import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { FilesystemBackend } from "./backends/filesystem.js";
import { createServer } from "./server.js";
import { homedir } from "os";
import { join } from "path";

function resolveDataDir(): string {
  // 1. --data-dir /path/to/dir  (recommended — visible in Claude/OpenAI Desktop config)
  const argIndex = process.argv.indexOf("--data-dir");
  if (argIndex !== -1 && process.argv[argIndex + 1]) {
    return process.argv[argIndex + 1];
  }
  // 2. ALLOURTHINGS_DATA_DIR env var  (escape hatch)
  if (process.env.ALLOURTHINGS_DATA_DIR) {
    return process.env.ALLOURTHINGS_DATA_DIR;
  }
  // 3. Default: ~/Documents/AllOurThings  (cross-platform, no cloud assumptions)
  return join(homedir(), "Documents", "AllOurThings");
}

const dataDir = resolveDataDir();
console.error(`[allourthings] data directory: ${dataDir}`);

const backend = new FilesystemBackend(dataDir);
const server = createServer(backend);
const transport = new StdioServerTransport();

await server.connect(transport);
