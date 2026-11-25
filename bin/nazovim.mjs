#!/usr/bin/env node
// npm launcher for NazoVim. Mirrors packages/nix/default.nix: deploy the
// config into an isolated NVIM_APPNAME and exec nvim with the same argv.
import { spawn } from "node:child_process";
import {
  chmodSync,
  cpSync,
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  rmSync,
  statSync,
} from "node:fs";
import { homedir } from "node:os";
import { delimiter, join } from "node:path";
import { fileURLToPath } from "node:url";

const APPNAME = "nvim-nazozokc";
const packageRoot = fileURLToPath(new URL("..", import.meta.url));
const configSource = join(packageRoot, "apps/nvim");
const nazoplugSource = join(packageRoot, "apps/nazoplug/lua/nazoplug");

/** Print a message to stderr and stop with an error exit code. */
function fail(message) {
  console.error(`nazovim: ${message}`);
  process.exit(1);
}

/** Read the package version from package.json. */
function version() {
  return JSON.parse(readFileSync(join(packageRoot, "package.json"), "utf8")).version;
}

/** Show launcher usage. */
function help() {
  console.log(`nazovim ${version()} — isolated Neovim configuration

Usage:
  npx nazovim [nvim args...]   launch Neovim with NazoVim
  npx nazovim --version        show launcher version
  npx nazovim --help           show this help
  npx nazovim -- --version     pass --version to Neovim

Environment:
  NAZOVIM_NVIM                 nvim executable (default: nvim on PATH)

Config: $XDG_CONFIG_HOME/${APPNAME} (default ~/.config/${APPNAME})
Data:   $XDG_DATA_HOME/${APPNAME} (default ~/.local/share/${APPNAME})`);
}

/** Return an executable path for name, or null when it is not on PATH. */
function findExecutable(name) {
  if (name.includes("/") || name.includes("\\")) {
    try {
      return statSync(name).isFile() ? name : null;
    } catch {
      return null;
    }
  }
  const extensions = process.platform === "win32" ? (process.env.PATHEXT ?? ".EXE;.CMD;.BAT").split(";") : [""];
  for (const dir of (process.env.PATH ?? "").split(delimiter)) {
    for (const extension of extensions) {
      const candidate = join(dir, `${name}${extension}`);
      try {
        const stat = statSync(candidate);
        if (stat.isFile() && (stat.mode & 0o111) !== 0) return candidate;
      } catch {
        // Not present in this PATH entry — keep looking.
      }
    }
  }
  return null;
}

/** Restore owner-write bits lost from archived files. */
function makeWritable(target) {
  let stat;
  try {
    stat = statSync(target);
  } catch {
    return;
  }
  chmodSync(target, stat.mode | 0o200);
  if (stat.isDirectory()) {
    for (const entry of readdirSync(target)) makeWritable(join(target, entry));
  }
}

/** Deploy the bundled config and seed the runtime lockfile. */
function prepare() {
  const configDir = join(process.env.XDG_CONFIG_HOME ?? join(homedir(), ".config"), APPNAME);
  const dataDir = join(process.env.XDG_DATA_HOME ?? join(homedir(), ".local/share"), APPNAME);

  // A symlink to an old npx cache (or Nix store) must not survive.
  rmSync(configDir, { recursive: true, force: true });
  cpSync(configSource, configDir, { recursive: true });
  cpSync(nazoplugSource, join(configDir, "lua/nazoplug"), { recursive: true });
  makeWritable(configDir);

  mkdirSync(dataDir, { recursive: true });
  const configLock = join(configDir, "nazoplug-lock.json");
  const dataLock = join(dataDir, "nazoplug-lock.json");
  if (!existsSync(dataLock) && existsSync(configLock)) {
    cpSync(configLock, dataLock);
    makeWritable(dataLock);
  }
}

/** Run nvim with the prepared environment and forward its exit status. */
function launch(nvim, args) {
  const child = spawn(nvim, args, {
    stdio: "inherit",
    env: { ...process.env, NVIM_APPNAME: APPNAME },
  });

  for (const signal of ["SIGINT", "SIGTERM", "SIGHUP"]) {
    process.on(signal, () => child.kill(signal));
  }
  child.on("error", (error) => fail(`failed to start ${nvim}: ${error.message}`));
  child.on("exit", (code, signal) => process.exit(code ?? (signal ? 1 : 0)));
}

const args = process.argv.slice(2);
if (args[0] === "--version" || args[0] === "-V") {
  console.log(version());
} else if (args[0] === "--help" || args[0] === "-h") {
  help();
} else {
  const nvim = findExecutable(process.env.NAZOVIM_NVIM || "nvim");
  if (!nvim) {
    fail("nvim not found. Install Neovim or set NAZOVIM_NVIM to its executable.");
  }
  try {
    prepare();
  } catch (error) {
    fail(`failed to deploy configuration: ${error.message}`);
  }
  launch(nvim, args[0] === "--" ? args.slice(1) : args);
}
