import { homedir } from "os";
import { join } from "path";

function expandTilde(p: string): string {
  if (p === "~" || p.startsWith("~/")) {
    return join(homedir(), p.slice(2));
  }
  return p;
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
