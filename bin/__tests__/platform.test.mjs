import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { dataDir, dataName, legacyDataDir, nvimEnvironment } from "../lib/paths.mjs";
import {
  executableExtensions,
  findExecutable,
  forwardableSignals,
  isWindows,
  needsShell,
} from "../lib/platform.mjs";

test("signal forwarding and shell detection match the platform", () => {
  assert.deepEqual(
    forwardableSignals(),
    isWindows ? ["SIGINT", "SIGTERM"] : ["SIGINT", "SIGTERM", "SIGHUP"],
  );
  assert.equal(needsShell("C:\\bin\\nvim.cmd"), isWindows);
  assert.equal(needsShell("nvim.BAT"), isWindows);
  assert.equal(needsShell("/usr/bin/nvim"), false);
});

test("nvim environment pins the same XDG bases as the launcher", () => {
  const root = mkdtempSync(join(tmpdir(), "nazovim-env-"));
  const previousConfig = process.env.XDG_CONFIG_HOME;
  const previousData = process.env.XDG_DATA_HOME;
  try {
    const config = join(root, "config");
    const data = join(root, "data");
    process.env.XDG_CONFIG_HOME = config;
    process.env.XDG_DATA_HOME = data;

    assert.equal(dataDir(), join(data, dataName()));
    assert.equal(legacyDataDir(), join(data, dataName("nvim-nazozokc")));

    const env = nvimEnvironment();
    assert.equal(env.NVIM_APPNAME, "nazovim");
    assert.equal(env.XDG_CONFIG_HOME, config);
    assert.equal(env.XDG_DATA_HOME, data);
  } finally {
    if (previousConfig === undefined) delete process.env.XDG_CONFIG_HOME;
    else process.env.XDG_CONFIG_HOME = previousConfig;
    if (previousData === undefined) delete process.env.XDG_DATA_HOME;
    else process.env.XDG_DATA_HOME = previousData;
    rmSync(root, { recursive: true, force: true });
  }
});

if (isWindows) {
  test("PATHEXT entries are normalised and deduplicated by the filesystem", () => {
    const previous = process.env.PATHEXT;
    try {
      process.env.PATHEXT = "EXE; .CMD ;;.BAT";
      assert.deepEqual(executableExtensions(), [".EXE", ".CMD", ".BAT"]);
    } finally {
      if (previous === undefined) delete process.env.PATHEXT;
      else process.env.PATHEXT = previous;
    }
  });

  test("data dirs carry the -data suffix Neovim uses on Windows", () => {
    assert.equal(dataName(), "nazovim-data");
    assert.equal(dataName("foo"), "foo-data");
  });

  test("finds nvim.exe without POSIX executable bits", () => {
    const root = mkdtempSync(join(tmpdir(), "nazovim-find-"));
    const previousPath = process.env.PATH;
    const previousPathExt = process.env.PATHEXT;
    try {
      const bin = join(root, "bin");
      mkdirSync(bin);
      writeFileSync(join(bin, "nvim.exe"), "fake");
      process.env.PATHEXT = "EXE;CMD";
      process.env.PATH = bin;

      assert.equal(findExecutable("nvim"), join(bin, "nvim.exe"));
      assert.equal(findExecutable(join(bin, "nvim")), join(bin, "nvim.exe"));
      assert.equal(findExecutable("missing"), null);
    } finally {
      if (previousPath === undefined) delete process.env.PATH;
      else process.env.PATH = previousPath;
      if (previousPathExt === undefined) delete process.env.PATHEXT;
      else process.env.PATHEXT = previousPathExt;
      rmSync(root, { recursive: true, force: true });
    }
  });
} else {
  test("POSIX paths and PATHEXT fallback stay unchanged", () => {
    assert.equal(dataName(), "nazovim");
    assert.deepEqual(executableExtensions(), [""]);
    assert.equal(needsShell("nvim.cmd"), false);
  });
}
