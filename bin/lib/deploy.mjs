// Config deployment: filesystem concerns only.
import {
  chmodSync,
  cpSync,
  existsSync,
  mkdirSync,
  readdirSync,
  rmSync,
  statSync,
} from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { configDir, dataDir, legacyDataDir } from "./paths.mjs";

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

/** Remove only the isolated config directory. Plugins in the data dir stay. */
export function remove() {
  const target = configDir();
  rmSync(target, { recursive: true, force: true });
  return target;
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
