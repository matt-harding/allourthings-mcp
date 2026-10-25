#!/usr/bin/env node
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { NativeBackend } from "./backends/native.js";
import { createServer, SERVER_VERSION } from "./server.js";
import { resolveDataDir } from "./config.js";

const args = process.argv.slice(2);
if (args.includes("--version") || args.includes("-v")) {
  console.log(SERVER_VERSION);
  process.exit(0);
}
if (args.includes("--help") || args.includes("-h")) {
  console.log(`allourthings-mcp-server ${SERVER_VERSION}

MCP server (stdio) for an AllOurThings vault. Normally launched by an MCP client
such as Claude Desktop rather than run directly.

Usage: allourthings-mcp-server [--data-dir <path>]

Vault location, in order of precedence:
  --data-dir <path>          command-line flag
  ALLOURTHINGS_DATA_DIR      environment variable
  config file                written by \`allourthings init\`

Options:
  -h, --help                 show this help
  -v, --version              show version`);
  process.exit(0);
}

let dataDir: string;
try {
  dataDir = resolveDataDir();
} catch (err) {
  console.error(`[allourthings] ${err instanceof Error ? err.message : String(err)}`);
  process.exit(1);
}
console.error(`[allourthings] data directory: ${dataDir}`);

const backend = new NativeBackend(dataDir);
const server = createServer(backend);
const transport = new StdioServerTransport();

await server.connect(transport);
