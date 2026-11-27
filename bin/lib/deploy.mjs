// Config deployment: filesystem concerns only.
import {
  chmodSync,
  cpSync,
  existsSync,
  lstatSync,
  mkdirSync,
  readdirSync,
  readlinkSync,
  rmSync,
  statSync,
} from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import {
  APPNAME,
  binDir,
  configDir,
  dataDir,
  legacyConfigDir,
  legacyDataDir,
  legacyStateDir,
  stateDir,
} from "./paths.mjs";

export const packageRoot = fileURLToPath(new URL("../..", import.meta.url));
const configSource = join(packageRoot, "apps", "nvim");
const nazoplugSource = join(packageRoot, "apps", "nazoplug", "lua", "nazoplug");

/** Restore owner-write bits lost from archived files. */
function makeWritable(target) {
  let stat;
  try {
    stat = statSync(target);
  } catch {
    return;
  }
  try {
    chmodSync(target, stat.mode | 0o200);
  } catch {
    // chmod is a no-op (or rejected) for Windows directories; real copy
    // failures are still reported by cpSync.
  }
  if (stat.isDirectory()) {
    for (const entry of readdirSync(target)) makeWritable(join(target, entry));
  }
}

function isSymlink(path) {
  try {
    return lstatSync(path).isSymbolicLink();
  } catch {
    return false;
  }
}

/** A `nvim` shim only belongs to us when its link target names NazoVim. */
function isNazovimLink(path) {
  if (!isSymlink(path)) return false;
  return /nazovim|nvim-nazozokc/i.test(readlinkSync(path));
}

/** Remove every NazoVim-owned path: config, plugins, state and bin shims. */
export function remove() {
  const removed = [];
  for (const target of [
    configDir(),
    dataDir(),
    stateDir(),
    legacyConfigDir(),
    legacyDataDir(),
    legacyStateDir(),
  ]) {
    rmSync(target, { recursive: true, force: true });
    removed.push(target);
  }

  const bin = binDir();
  const own = join(bin, APPNAME);
  if (existsSync(own) || isSymlink(own)) {
    rmSync(own, { force: true });
    removed.push(own);
  }
  const nvim = join(bin, "nvim");
  if (isNazovimLink(nvim)) {
    rmSync(nvim, { force: true });
    removed.push(nvim);
  }
  return removed;
}

/** Deploy the bundled config and seed the runtime lockfile. */
export function prepare() {
  const config = configDir();
  const data = dataDir();

  // A symlink to an old npx cache (or Nix store) must not survive.
  rmSync(config, { recursive: true, force: true });
  cpSync(configSource, config, { recursive: true });
  cpSync(nazoplugSource, join(config, "lua", "nazoplug"), { recursive: true });
  makeWritable(config);

  mkdirSync(data, { recursive: true });

  // Older releases used a different NVIM_APPNAME; carry their plugins over
  // so a version upgrade does not turn every require() into "module not found".
  const site = join(data, "site");
  const legacySite = join(legacyDataDir(), "site");
  if (!existsSync(site) && existsSync(legacySite)) {
    cpSync(legacySite, site, { recursive: true });
  }

  const configLock = join(config, "nazoplug-lock.json");
  const dataLock = join(data, "nazoplug-lock.json");
  if (!existsSync(dataLock) && existsSync(configLock)) {
    cpSync(configLock, dataLock);
    makeWritable(dataLock);
  }
}
