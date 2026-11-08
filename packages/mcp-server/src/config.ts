import { readFileSync, statSync } from "fs";
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
  const xdg = process.env.XDG_CACHE_HOME;
  return join(xdg ? expandTilde(xdg) : join(homedir(), ".cache"), "allourthings");
}

export function platformConfigPath(): string {
  if (platform() === "win32") {
    return join(process.env.APPDATA ?? join(homedir(), "AppData", "Roaming"), "allourthings", "config.json");
  }
  if (platform() === "darwin") {
    return join(homedir(), "Library", "Application Support", "allourthings", "config.json");
  }
  const xdg = process.env.XDG_CONFIG_HOME;
  return join(xdg ? expandTilde(xdg) : join(homedir(), ".config"), "allourthings", "config.json");
}

export function readConfigFile(): string | null {
  try {
    const raw = readFileSync(platformConfigPath(), "utf8");
    const parsed = JSON.parse(raw) as unknown;
    if (
      parsed !== null &&
      typeof parsed === "object" &&
      "data_dir" in parsed &&
      typeof (parsed as Record<string, unknown>).data_dir === "string"
    ) {
      const dir = (parsed as { data_dir: string }).data_dir;
      return dir ? expandTilde(dir) : null;
    }
  } catch {
    // file missing or malformed — treat as unconfigured
  }
  return null;
}

export const NO_VAULT_MESSAGE =
  "No AllOurThings vault is configured. Choose the folder that holds your inventory by doing one of these: " +
  "pass `--data-dir <folder>` in your AI app's MCP settings, set `ALLOURTHINGS_DATA_DIR`, or run `npx @allourthings/cli init`. " +
  "If you use the AllOurThings iOS app, choose the same folder it uses (e.g. in iCloud Drive).";

export function resolveDataDir(
  argv: string[] = process.argv,
  env: Record<string, string | undefined> = process.env,
  configReader: () => string | null = readConfigFile
): string {
  const argIndex = argv.indexOf("--data-dir");
  if (argIndex !== -1 && argv[argIndex + 1]) {
    return expandTilde(argv[argIndex + 1]);
  }
  if (env.ALLOURTHINGS_DATA_DIR) {
    return expandTilde(env.ALLOURTHINGS_DATA_DIR);
  }
  const fromConfig = configReader();
  if (fromConfig) return expandTilde(fromConfig);
  throw new Error(NO_VAULT_MESSAGE);
}

/** Throws unless `dataDir` is an existing folder, so a mistyped path isn't silently created on first write. */
export function assertVaultFolder(dataDir: string): void {
  let isDir: boolean;
  try {
    isDir = statSync(dataDir).isDirectory();
  } catch {
    throw new Error(
      `The vault folder doesn't exist: ${dataDir}. Check the path in your AI app's MCP settings, or run \`npx @allourthings/cli init\` to create a new vault.`
    );
  }
  if (!isDir) throw new Error(`The vault path is a file, not a folder: ${dataDir}`);
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
