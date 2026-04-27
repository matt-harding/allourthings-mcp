import { createHash } from "crypto";
import { homedir, platform } from "os";
import { join } from "path";

function expandTilde(p: string): string {
  if (p === "~" || p.startsWith("~/")) {
    return join(homedir(), p.slice(2));
  }
  return p;
}

function platformCacheBase(): string {
  if (platform() === "win32") {
    return join(process.env.LOCALAPPDATA ?? join(homedir(), "AppData", "Local"), "allourthings");
  }
  if (platform() === "darwin") {
    return join(homedir(), "Library", "Caches", "allourthings");
  }
  // Linux / other: XDG_CACHE_HOME or ~/.cache
  const xdg = process.env.XDG_CACHE_HOME;
  return join(xdg ? expandTilde(xdg) : join(homedir(), ".cache"), "allourthings");
}

export function resolveDataDir(
  argv: string[] = process.argv,
  env: Record<string, string | undefined> = process.env
): string {
  const argIndex = argv.indexOf("--data-dir");
  if (argIndex !== -1 && argv[argIndex + 1]) {
    return expandTilde(argv[argIndex + 1]);
  }
  if (env.ALLOURTHINGS_DATA_DIR) {
    return expandTilde(env.ALLOURTHINGS_DATA_DIR);
  }
  return join(homedir(), "Documents", "AllOurThings");
}

/**
 * Derives a stable, local, never-synced cache directory for the given vault.
 * Each distinct data directory gets its own subdirectory via a hash of its
 * absolute path, so multiple vaults never share a cache.
 */
export function resolveCacheDir(dataDir: string): string {
  const hash = createHash("sha256").update(dataDir).digest("hex").slice(0, 16);
  return join(platformCacheBase(), hash);
}
