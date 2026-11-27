#!/usr/bin/env node
// npm launcher for NazoVim. Mirrors packages/nix/default.nix: deploy the
// config into an isolated NVIM_APPNAME and exec nvim with the same argv.
import { spawn } from "node:child_process";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { packageRoot, prepare, remove } from "./lib/deploy.mjs";
import { binDir, configDir, dataDir, nvimEnvironment } from "./lib/paths.mjs";
import { findExecutable, forwardableSignals, needsShell } from "./lib/platform.mjs";

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
  npx nazovim remove           delete all NazoVim config, data and bin shims
  npx nazovim --version        show launcher version
  npx nazovim --help           show this help
  npx nazovim -- --version     pass --version to Neovim

Environment:
  NAZOVIM_NVIM                 nvim executable (default: nvim on PATH)
  XDG_CONFIG_HOME              config base (default ~/.config)
  XDG_DATA_HOME                data base (default ~/.local/share)
  XDG_STATE_HOME               state base (default ~/.local/state)
  XDG_BIN_HOME                 shim base (default ~/.local/bin)

Config: ${configDir()}
Data:   ${dataDir()}
Bin:    ${binDir()}`);
}

/** Run nvim with the prepared environment and forward its exit status. */
function launch(nvim, args) {
  const child = spawn(nvim, args, {
    stdio: "inherit",
    env: nvimEnvironment(),
    shell: needsShell(nvim),
  });

  for (const signal of forwardableSignals()) {
    process.on(signal, () => child.kill(signal));
  }
  child.on("error", (error) => fail(`failed to start ${nvim}: ${error.message}`));
  child.on("exit", (code, signal) => process.exit(code ?? (signal ? 1 : 0)));
}

const args = process.argv.slice(2);
if (args[0] === "remove") {
  try {
    const removed = remove();
    console.log(`Removed ${removed.length} NazoVim path(s):\n${removed.map((path) => `  ${path}`).join("\n")}`);
  } catch (error) {
    fail(`failed to remove configuration: ${error.message}`);
  }
} else if (args[0] === "--version" || args[0] === "-V") {
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
