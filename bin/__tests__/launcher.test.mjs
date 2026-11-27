import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, existsSync, lstatSync, mkdirSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { delimiter, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";
import { APPNAME, LEGACY_APPNAME, dataName } from "../lib/paths.mjs";
import { isWindows } from "../lib/platform.mjs";

const launcher = fileURLToPath(new URL("../nazovim.mjs", import.meta.url));
const version = JSON.parse(readFileSync(new URL("../../package.json", import.meta.url), "utf8")).version;
const DATA_NAME = dataName();
const LEGACY_DATA_NAME = dataName("nvim-nazozokc");

/** symlink with a type that works without admin rights on Windows. */
function link(target, path) {
  if (isWindows) symlinkSync(target, path, "junction");
  else symlinkSync(target, path);
}

/** Create an isolated environment with a fake nvim that records its argv. */
function sandbox() {
  const root = mkdtempSync(join(tmpdir(), "nazovim-launcher-"));
  const bin = join(root, "bin");
  const config = join(root, "config");
  const data = join(root, "data");
  const state = join(root, "state");
  const shims = join(root, "shims");
  const log = join(root, "nvim.log");
  const nvim = join(bin, isWindows ? "nvim.cmd" : "nvim");
  mkdirSync(bin);
  mkdirSync(config);
  mkdirSync(data);
  mkdirSync(state);
  mkdirSync(shims);

  if (isWindows) {
    writeFileSync(
      nvim,
      [
        "@echo off",
        `echo APPNAME=%NVIM_APPNAME%>> "%FAKE_NVIM_LOG%"`,
        `echo CONFIG=%XDG_CONFIG_HOME%>> "%FAKE_NVIM_LOG%"`,
        `echo DATA=%XDG_DATA_HOME%>> "%FAKE_NVIM_LOG%"`,
        `echo AUTO=%NAZOVIM_AUTO_INSTALL%>> "%FAKE_NVIM_LOG%"`,
        `for %%A in (%*) do echo ARG=%%~A>> "%FAKE_NVIM_LOG%"`,
        "",
      ].join("\r\n"),
    );
  } else {
    writeFileSync(
      nvim,
      `#!/bin/sh\n{ printf 'APPNAME=%s\\n' "$NVIM_APPNAME"; printf 'CONFIG=%s\\n' "$XDG_CONFIG_HOME"; printf 'DATA=%s\\n' "$XDG_DATA_HOME"; printf 'AUTO=%s\\n' "$NAZOVIM_AUTO_INSTALL"; printf 'ARG=%s\\n' "$@"; } > "$FAKE_NVIM_LOG"\n`,
      { mode: 0o755 },
    );
    chmodSync(nvim, 0o755);
  }

  return { root, bin, config, data, state, shims, log, nvim };
}

/** Run the launcher with the sandbox environment. */
function run(box, args = [], overrides = {}) {
  return spawnSync(process.execPath, [launcher, ...args], {
    encoding: "utf8",
    env: {
      ...process.env,
      HOME: box.root,
      USERPROFILE: box.root,
      XDG_CONFIG_HOME: box.config,
      XDG_DATA_HOME: box.data,
      XDG_STATE_HOME: box.state,
      XDG_BIN_HOME: box.shims,
      PATH: `${box.bin}${delimiter}${process.env.PATH}`,
      PATHEXT: ".COM;.EXE;.BAT;.CMD",
      FAKE_NVIM_LOG: box.log,
      NAZOVIM_NVIM: "",
      ...overrides,
    },
  });
}

function cleanup(box) {
  rmSync(box.root, { recursive: true, force: true });
}

test("deploys config, seeds lockfile and passes argv to nvim", () => {
  const box = sandbox();
  try {
    const result = run(box, ["file.txt", "--clean"]);
    assert.equal(result.status, 0, result.stderr);
    const log = readFileSync(box.log, "utf8");
    assert.match(log, /APPNAME=nazovim/);
    assert.ok(log.includes(`CONFIG=${box.config}`), log);
    assert.ok(log.includes(`DATA=${box.data}`), log);
    assert.match(log, /AUTO=1/);
    assert.match(log, /ARG=file\.txt/);
    assert.match(log, /ARG=--clean/);
    assert.ok(existsSync(join(box.config, APPNAME, "init.lua")));
    assert.ok(existsSync(join(box.config, APPNAME, "lua", "nazoplug", "init.lua")));
    assert.equal(
      readFileSync(join(box.data, DATA_NAME, "nazoplug-lock.json"), "utf8"),
      readFileSync(join(box.config, APPNAME, "nazoplug-lock.json"), "utf8"),
    );
  } finally {
    cleanup(box);
  }
});

test("migrates plugins from the legacy data dir on first launch", () => {
  const box = sandbox();
  try {
    const legacyPlugin = join(box.data, LEGACY_DATA_NAME, "site", "pack", "nazoplug", "opt", "flash.nvim", "lua", "flash");
    mkdirSync(legacyPlugin, { recursive: true });
    writeFileSync(join(legacyPlugin, "init.lua"), "-- legacy flash");

    const result = run(box);
    assert.equal(result.status, 0, result.stderr);
    assert.equal(
      readFileSync(join(box.data, DATA_NAME, "site", "pack", "nazoplug", "opt", "flash.nvim", "lua", "flash", "init.lua"), "utf8"),
      "-- legacy flash",
    );
    assert.ok(existsSync(join(legacyPlugin, "init.lua")));
    assert.equal(
      readFileSync(join(box.data, DATA_NAME, "nazoplug-lock.json"), "utf8"),
      readFileSync(join(box.config, APPNAME, "nazoplug-lock.json"), "utf8"),
    );
  } finally {
    cleanup(box);
  }
});

test("keeps an existing plugin dir instead of copying the legacy one", () => {
  const box = sandbox();
  try {
    const current = join(box.data, DATA_NAME, "site", "pack", "nazoplug", "opt", "flash.nvim");
    const legacy = join(box.data, LEGACY_DATA_NAME, "site", "pack", "nazoplug", "opt", "flash.nvim");
    mkdirSync(current, { recursive: true });
    writeFileSync(join(current, "marker"), "current");
    mkdirSync(legacy, { recursive: true });
    writeFileSync(join(legacy, "marker"), "legacy");

    const result = run(box);
    assert.equal(result.status, 0, result.stderr);
    assert.equal(readFileSync(join(current, "marker"), "utf8"), "current");
  } finally {
    cleanup(box);
  }
});

test("replaces a stale config link and keeps an existing lockfile", () => {
  const box = sandbox();
  try {
    const stale = join(box.root, "stale");
    mkdirSync(stale);
    link(stale, join(box.config, APPNAME));
    mkdirSync(join(box.data, DATA_NAME), { recursive: true });
    writeFileSync(join(box.data, DATA_NAME, "nazoplug-lock.json"), "{}");

    const result = run(box);
    assert.equal(result.status, 0, result.stderr);
    assert.equal(lstatSync(join(box.config, APPNAME)).isSymbolicLink(), false);
    assert.equal(readFileSync(join(box.data, DATA_NAME, "nazoplug-lock.json"), "utf8"), "{}");
  } finally {
    cleanup(box);
  }
});

test("honors NAZOVIM_NVIM and forwards -- separator", () => {
  const box = sandbox();
  try {
    const result = run(box, ["--", "--version"], { NAZOVIM_NVIM: box.nvim });
    assert.equal(result.status, 0, result.stderr);
    assert.match(readFileSync(box.log, "utf8"), /ARG=--version/);
    assert.doesNotMatch(result.stdout, new RegExp(`^${version}$`));
  } finally {
    cleanup(box);
  }
});

test("fails clearly when nvim is missing", () => {
  const box = sandbox();
  try {
    const result = run(box, [], { PATH: join(box.root, "empty") });
    assert.equal(result.status, 1);
    assert.match(result.stderr, /nvim not found/);
    assert.equal(existsSync(box.log), false);
  } finally {
    cleanup(box);
  }
});

test("prints launcher version and help without launching nvim", () => {
  const box = sandbox();
  try {
    const versionResult = run(box, ["--version"]);
    assert.equal(versionResult.status, 0, versionResult.stderr);
    assert.equal(versionResult.stdout.trim(), version);
    const helpResult = run(box, ["--help"]);
    assert.equal(helpResult.status, 0, helpResult.stderr);
    assert.match(helpResult.stdout, /NAZOVIM_NVIM/);
    assert.match(helpResult.stdout, /XDG_DATA_HOME/);
    assert.equal(existsSync(box.log), false);
  } finally {
    cleanup(box);
  }
});

test("remove deletes config, data, state and legacy dirs", () => {
  const box = sandbox();
  try {
    const dirs = [
      join(box.config, APPNAME),
      join(box.data, DATA_NAME),
      join(box.state, DATA_NAME),
      join(box.config, LEGACY_APPNAME),
      join(box.data, LEGACY_DATA_NAME),
      join(box.state, LEGACY_DATA_NAME),
    ];
    for (const dir of dirs) {
      mkdirSync(dir, { recursive: true });
      writeFileSync(join(dir, "marker"), "x");
    }

    const result = run(box, ["remove"]);
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /Removed 6 NazoVim path/);
    for (const dir of dirs) {
      assert.equal(existsSync(dir), false, dir);
    }
    assert.equal(existsSync(box.log), false);
  } finally {
    cleanup(box);
  }
});

test("remove deletes NazoVim bin shims but keeps unrelated executables", () => {
  const box = sandbox();
  try {
    const own = join(box.shims, "nazovim");
    writeFileSync(own, "#!/bin/sh\n");
    const nvimLink = join(box.shims, "nvim");
    const nvimTarget = join(box.root, "store-nazovim");
    mkdirSync(nvimTarget);
    link(nvimTarget, nvimLink);
    const other = join(box.shims, "vim");
    writeFileSync(other, "#!/bin/sh\n");
    const foreign = join(box.shims, "other-nvim");
    link(join(box.root, "real-nvim"), foreign);

    const result = run(box, ["remove"]);
    assert.equal(result.status, 0, result.stderr);
    assert.equal(existsSync(own), false);
    assert.equal(lstatSync(nvimLink, { throwIfNoEntry: false }), undefined);
    assert.ok(existsSync(other));
    assert.ok(lstatSync(foreign).isSymbolicLink());
  } finally {
    cleanup(box);
  }
});

test("remove unlinks a config symlink without touching its target", () => {
  const box = sandbox();
  try {
    const target = join(box.root, "store-config");
    mkdirSync(target);
    writeFileSync(join(target, "init.lua"), "x");
    link(target, join(box.config, APPNAME));

    const result = run(box, ["remove"]);
    assert.equal(result.status, 0, result.stderr);
    assert.equal(existsSync(join(box.config, APPNAME)), false);
    assert.ok(existsSync(join(target, "init.lua")));
  } finally {
    cleanup(box);
  }
});
