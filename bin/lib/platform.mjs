// Platform-specific executable discovery and process handling.
import { statSync } from "node:fs";
import { delimiter, extname, join } from "node:path";

export const isWindows = process.platform === "win32";

/** PATHEXT entries, normalised with a leading dot. */
export function executableExtensions() {
  if (!isWindows) return [""];
  return (process.env.PATHEXT ?? ".COM;.EXE;.BAT;.CMD")
    .split(";")
    .map((entry) => entry.trim())
    .filter(Boolean)
    .map((entry) => (entry.startsWith(".") ? entry : `.${entry}`));
}

function isExecutable(stat) {
  // Windows mode bits do not describe executability: a real nvim.exe often
  // reports 0o666, so the POSIX bit check would hide every executable.
  return stat.isFile() && (isWindows || (stat.mode & 0o111) !== 0);
}

function existing(path) {
  try {
    return isExecutable(statSync(path)) ? path : null;
  } catch {
    return null;
  }
}

/** Resolve name against PATH, or treat it as an explicit path. */
export function findExecutable(name) {
  if (!name) return null;
  if (name.includes("/") || name.includes("\\")) {
    const candidates = isWindows && !extname(name)
      ? executableExtensions().map((extension) => `${name}${extension}`)
      : [name];
    for (const candidate of candidates) {
      const found = existing(candidate);
      if (found) return found;
    }
    return null;
  }

  for (const dir of (process.env.PATH ?? "").split(delimiter)) {
    for (const extension of executableExtensions()) {
      const found = existing(join(dir, `${name}${extension}`));
      if (found) return found;
    }
  }
  return null;
}

/** .cmd/.bat shims can only be spawned through cmd.exe on Windows. */
export function needsShell(command) {
  return isWindows && [".cmd", ".bat"].includes(extname(command).toLowerCase());
}

/** SIGHUP cannot be sent to a child process on Windows. */
export function forwardableSignals() {
  return isWindows ? ["SIGINT", "SIGTERM"] : ["SIGINT", "SIGTERM", "SIGHUP"];
}
