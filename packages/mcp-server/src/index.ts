#!/usr/bin/env node
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { NativeBackend } from "./backends/native.js";
import { createServer } from "./server.js";
import { resolveDataDir } from "./config.js";

const dataDir = resolveDataDir();
console.error(`[allourthings] data directory: ${dataDir}`);

const backend = new NativeBackend(dataDir);
const server = createServer(backend);
const transport = new StdioServerTransport();

await server.connect(transport);
