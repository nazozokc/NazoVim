// Directory layout shared by the launcher and the environment handed to nvim.
// Neovim appends "-data" to NVIM_APPNAME for its data/state dirs on Windows
// (src/nvim/os/stdpaths.c), so the launcher has to use the same name.
import { homedir } from "node:os";
import { join } from "node:path";
import { isWindows } from "./platform.mjs";

export const APPNAME = "nazovim";
export const LEGACY_APPNAME = "nvim-nazozokc";

/** Base directory Neovim treats as $XDG_CONFIG_HOME. */
export function configBase() {
  return process.env.XDG_CONFIG_HOME ?? join(homedir(), ".config");
}

/** Base directory Neovim treats as $XDG_DATA_HOME. */
export function dataBase() {
  return process.env.XDG_DATA_HOME ?? join(homedir(), ".local", "share");
}

/** Directory name Neovim derives from NVIM_APPNAME. */
export function dataName(appname = APPNAME) {
  return isWindows ? `${appname}-data` : appname;
}

export function configDir() {
  return join(configBase(), APPNAME);
}

export function dataDir() {
  return join(dataBase(), dataName());
}

/** Directory Neovim uses for state (shada, undo, etc.). */
export function stateDir(appname = APPNAME) {
  return join(process.env.XDG_STATE_HOME ?? join(homedir(), ".local", "state"), dataName(appname));
}

export function legacyConfigDir() {
  return join(configBase(), LEGACY_APPNAME);
}

export function legacyDataDir() {
  return join(dataBase(), dataName(LEGACY_APPNAME));
}

export function legacyStateDir() {
  return stateDir(LEGACY_APPNAME);
}

/** Where users commonly symlink the launcher executable. */
export function binDir() {
  return process.env.XDG_BIN_HOME ?? join(homedir(), ".local", "bin");
}

/** Pass the exact bases the launcher deployed into. Without this, Windows
 * nvim falls back to ~/AppData/Local and finds neither config nor plugins. */
export function nvimEnvironment() {
  return {
    ...process.env,
    NVIM_APPNAME: APPNAME,
    NAZOVIM_AUTO_INSTALL: "1",
    XDG_CONFIG_HOME: configBase(),
    XDG_DATA_HOME: dataBase(),
  };
}
