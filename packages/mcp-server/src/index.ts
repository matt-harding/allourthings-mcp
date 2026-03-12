import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { FilesystemBackend } from "./backends/filesystem.js";
import { createServer } from "./server.js";
import { homedir } from "os";
import { join } from "path";

const catalogPath =
  process.env.CATALOG_PATH ??
  join(homedir(), "Library", "Mobile Documents", "com~apple~CloudDocs", "AllOurThings", "catalog.json");

const backend = new FilesystemBackend(catalogPath);
const server = createServer(backend);
const transport = new StdioServerTransport();

await server.connect(transport);
