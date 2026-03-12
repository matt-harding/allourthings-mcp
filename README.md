# All Our Things

> Your stuff, your data, your choice of storage. AI-powered answers about everything you own.

A monorepo for the All Our Things household inventory system. Ask your AI assistant natural language questions about everything you own — appliances, furniture, subscriptions, warranties, and more.

**Website:** [allourthings.io](https://allourthings.io)

## Packages

| Package | Description |
|---|---|
| [`packages/mcp-server`](./packages/mcp-server) | TypeScript MCP server — the core of the system |
| [`packages/website`](./packages/website) | Astro static site — allourthings.io |

---

## MCP Server

The MCP server exposes your household inventory to any MCP-compatible AI client (Claude Desktop, VS Code, Cursor, etc.) via six tools:

| Tool | Description |
|---|---|
| `add_item` | Add a new item to your inventory |
| `get_item` | Retrieve an item by ID or name |
| `list_items` | List all items, optionally filtered by category, location, or tags |
| `update_item` | Update fields on an existing item |
| `delete_item` | Delete an item by ID |
| `search_items` | Full-text search across all item fields |

### Storage

By default, your inventory is stored as a JSON file on iCloud Drive:

```
~/Library/Mobile Documents/com~apple~CloudDocs/AllOurThings/catalog.json
```

Override the location by setting the `CATALOG_PATH` environment variable.

### Data schema

Every item has a small set of required fields (`id`, `name`, `created_at`, `updated_at`) and a collection of well-known optional fields (`category`, `brand`, `model`, `purchase_date`, `purchase_price`, `warranty_expires`, `location`, `tags`, etc.). You can also store any custom fields you like — they are preserved as-is.

---

## Development

### Prerequisites

- [Bun](https://bun.sh) — `brew install bun`
- [Task](https://taskfile.dev) — `brew install go-task`

### Install dependencies

```bash
bun install
```

### Run in dev mode

```bash
task dev           # MCP server in watch mode
task website:dev   # Website dev server
```

### Build

```bash
task build         # Compile MCP server to dist/
task website:build # Build website to packages/website/dist/
```

### Typecheck

```bash
task typecheck
```

---

## Testing

### Quick start with Task

```bash
# Seed test data + open MCP Inspector in one step
task test

# Or separately:
task seed:reset   # populate catalog.json with 12 realistic test items
task inspect      # open MCP Inspector (dev mode, no build required)
```

All tasks use `./catalog.json` by default — your real iCloud catalog is never touched. Override with `CATALOG_PATH=/path/to/file task <command>`.

Available tasks:

| Task | Description |
|---|---|
| `task test` | Seed + open Inspector — fastest way to start |
| `task seed` | Append test items to catalog |
| `task seed:reset` | Clear catalog and re-seed |
| `task inspect` | MCP Inspector in dev mode |
| `task inspect:prod` | Build, then MCP Inspector against dist |
| `task dev` | Start MCP server in watch mode |
| `task build` | Compile MCP server to dist/ |
| `task typecheck` | Run TypeScript type checking |
| `task clean` | Remove dist/ |
| `task clean:catalog` | Delete local dev catalog |
| `task website:dev` | Start website dev server |
| `task website:build` | Build website for production |
| `task website:deploy` | Build and deploy website to Cloudflare Pages |

---

## Connecting to Claude Desktop

Add the following to your Claude Desktop config (`~/Library/Application Support/Claude/claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "allourthings": {
      "command": "bun",
      "args": ["/path/to/AllOurThings/packages/mcp-server/dist/index.js"]
    }
  }
}
```

Or in dev mode (no build step required):

```json
{
  "mcpServers": {
    "allourthings": {
      "command": "bun",
      "args": ["/path/to/AllOurThings/packages/mcp-server/src/index.ts"]
    }
  }
}
```

Then restart Claude Desktop. You can now ask things like:

- *"Add my Bosch washing machine, bought from John Lewis for £599 in January 2024 with a 2 year warranty"*
- *"What appliances do I own?"*
- *"What's in the kitchen?"*
- *"When does my washing machine warranty expire?"*
- *"Search for anything related to Samsung"*
