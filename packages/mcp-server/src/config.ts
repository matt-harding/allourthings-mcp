import { homedir } from "os";
import { join } from "path";

export function resolveDataDir(
  argv: string[] = process.argv,
  env: Record<string, string | undefined> = process.env
): string {
  const argIndex = argv.indexOf("--data-dir");
  if (argIndex !== -1 && argv[argIndex + 1]) {
    return argv[argIndex + 1];
  }
  if (env.ALLOURTHINGS_DATA_DIR) {
    return env.ALLOURTHINGS_DATA_DIR;
  }
  return join(homedir(), "Documents", "AllOurThings");
}
