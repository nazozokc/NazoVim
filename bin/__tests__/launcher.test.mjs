import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, existsSync, lstatSync, mkdirSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const launcher = fileURLToPath(new URL("../nazovim.mjs", import.meta.url));
const version = JSON.parse(readFileSync(new URL("../../package.json", import.meta.url), "utf8")).version;

/** Create an isolated environment with a fake nvim that records its argv. */
function sandbox() {
  const root = mkdtempSync(join(tmpdir(), "nazovim-launcher-"));
  const bin = join(root, "bin");
  const config = join(root, "config");
  const data = join(root, "data");
  const log = join(root, "nvim.log");
  mkdirSync(bin);
  mkdirSync(config);
  mkdirSync(data);
  writeFileSync(
    join(bin, "nvim"),
    `#!/bin/sh\n{ printf 'APPNAME=%s\\n' "$NVIM_APPNAME"; printf 'ARG=%s\\n' "$@"; } > "$FAKE_NVIM_LOG"\n`,
    { mode: 0o755 },
  );
  chmodSync(join(bin, "nvim"), 0o755);
  return { root, bin, config, data, log };
}

/** Run the launcher with the sandbox environment. */
function run(box, args = [], overrides = {}) {
  return spawnSync(process.execPath, [launcher, ...args], {
    encoding: "utf8",
    env: {
      ...process.env,
      HOME: box.root,
      XDG_CONFIG_HOME: box.config,
      XDG_DATA_HOME: box.data,
      PATH: `${box.bin}:${process.env.PATH}`,
      FAKE_NVIM_LOG: box.log,
      NAZOVIM_NVIM: "",
      ...overrides,
    },
  });
}

function cleanup(box) {
  rmSync(box.root, { recursive: true, force: true });
}

if (process.platform === "win32") {
  test("launcher tests require a POSIX shell", { skip: true }, () => {});
} else {
  test("deploys config, seeds lockfile and passes argv to nvim", () => {
    const box = sandbox();
    try {
      const result = run(box, ["file.txt", "--clean"]);
      assert.equal(result.status, 0, result.stderr);
      assert.match(readFileSync(box.log, "utf8"), /APPNAME=nazovim/);
      assert.match(readFileSync(box.log, "utf8"), /ARG=file\.txt/);
      assert.match(readFileSync(box.log, "utf8"), /ARG=--clean/);
      assert.ok(existsSync(join(box.config, "nazovim/init.lua")));
      assert.ok(existsSync(join(box.config, "nazovim/lua/nazoplug/init.lua")));
      assert.equal(
        readFileSync(join(box.data, "nazovim/nazoplug-lock.json"), "utf8"),
        readFileSync(join(box.config, "nazovim/nazoplug-lock.json"), "utf8"),
      );
    } finally {
      cleanup(box);
    }
  });

  test("migrates plugins from the legacy data dir on first launch", () => {
    const box = sandbox();
    try {
      const legacyPlugin = join(box.data, "nvim-nazozokc/site/pack/nazoplug/opt/flash.nvim/lua/flash");
      mkdirSync(legacyPlugin, { recursive: true });
      writeFileSync(join(legacyPlugin, "init.lua"), "-- legacy flash");

      const result = run(box);
      assert.equal(result.status, 0, result.stderr);
      assert.equal(
        readFileSync(join(box.data, "nazovim/site/pack/nazoplug/opt/flash.nvim/lua/flash/init.lua"), "utf8"),
        "-- legacy flash",
      );
      assert.ok(existsSync(join(legacyPlugin, "init.lua")));
      assert.equal(
        readFileSync(join(box.data, "nazovim/nazoplug-lock.json"), "utf8"),
        readFileSync(join(box.config, "nazovim/nazoplug-lock.json"), "utf8"),
      );
    } finally {
      cleanup(box);
    }
  });

  test("keeps an existing plugin dir instead of copying the legacy one", () => {
    const box = sandbox();
    try {
      const current = join(box.data, "nazovim/site/pack/nazoplug/opt/flash.nvim");
      const legacy = join(box.data, "nvim-nazozokc/site/pack/nazoplug/opt/flash.nvim");
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

  test("replaces a stale config symlink and keeps an existing lockfile", () => {
    const box = sandbox();
    try {
      const stale = join(box.root, "stale");
      mkdirSync(stale);
      symlinkSync(stale, join(box.config, "nazovim"));
      mkdirSync(join(box.data, "nazovim"));
      writeFileSync(join(box.data, "nazovim/nazoplug-lock.json"), "{}");

      const result = run(box);
      assert.equal(result.status, 0, result.stderr);
      assert.equal(lstatSync(join(box.config, "nazovim")).isSymbolicLink(), false);
      assert.equal(readFileSync(join(box.data, "nazovim/nazoplug-lock.json"), "utf8"), "{}");
    } finally {
      cleanup(box);
    }
  });

  test("honors NAZOVIM_NVIM and forwards -- separator", () => {
    const box = sandbox();
    try {
      const result = run(box, ["--", "--version"], { NAZOVIM_NVIM: join(box.bin, "nvim") });
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
      assert.equal(existsSync(box.log), false);
    } finally {
      cleanup(box);
    }
  });

  test("remove deletes only the config dir, keeping the data dir", () => {
    const box = sandbox();
    try {
      mkdirSync(join(box.config, "nazovim"), { recursive: true });
      writeFileSync(join(box.config, "nazovim/init.lua"), "x");
      mkdirSync(join(box.data, "nazovim"), { recursive: true });
      writeFileSync(join(box.data, "nazovim/nazoplug-lock.json"), "{}");

      const result = run(box, ["remove"]);
      assert.equal(result.status, 0, result.stderr);
      assert.match(result.stdout, /Removed /);
      assert.equal(existsSync(join(box.config, "nazovim")), false);
      assert.ok(existsSync(join(box.data, "nazovim/nazoplug-lock.json")));
      assert.equal(existsSync(box.log), false);
    } finally {
      cleanup(box);
    }
  });

  test("remove unlinks a config symlink without touching its target", () => {
    const box = sandbox();
    try {
      const target = join(box.root, "nix-store-config");
      mkdirSync(target);
      writeFileSync(join(target, "init.lua"), "x");
      symlinkSync(target, join(box.config, "nazovim"));

      const result = run(box, ["remove"]);
      assert.equal(result.status, 0, result.stderr);
      assert.equal(existsSync(join(box.config, "nazovim")), false);
      assert.ok(existsSync(join(target, "init.lua")));
    } finally {
      cleanup(box);
    }
  });
}
