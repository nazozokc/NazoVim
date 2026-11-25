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
      assert.match(readFileSync(box.log, "utf8"), /APPNAME=nvim-nazozokc/);
      assert.match(readFileSync(box.log, "utf8"), /ARG=file\.txt/);
      assert.match(readFileSync(box.log, "utf8"), /ARG=--clean/);
      assert.ok(existsSync(join(box.config, "nvim-nazozokc/init.lua")));
      assert.ok(existsSync(join(box.config, "nvim-nazozokc/lua/nazoplug/init.lua")));
      assert.equal(
        readFileSync(join(box.data, "nvim-nazozokc/nazoplug-lock.json"), "utf8"),
        readFileSync(join(box.config, "nvim-nazozokc/nazoplug-lock.json"), "utf8"),
      );
    } finally {
      cleanup(box);
    }
  });

  test("replaces a stale config symlink and keeps an existing lockfile", () => {
    const box = sandbox();
    try {
      const stale = join(box.root, "stale");
      mkdirSync(stale);
      symlinkSync(stale, join(box.config, "nvim-nazozokc"));
      mkdirSync(join(box.data, "nvim-nazozokc"));
      writeFileSync(join(box.data, "nvim-nazozokc/nazoplug-lock.json"), "{}");

      const result = run(box);
      assert.equal(result.status, 0, result.stderr);
      assert.equal(lstatSync(join(box.config, "nvim-nazozokc")).isSymbolicLink(), false);
      assert.equal(readFileSync(join(box.data, "nvim-nazozokc/nazoplug-lock.json"), "utf8"), "{}");
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
}
