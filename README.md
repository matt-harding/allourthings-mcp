# All Our Things

> Your stuff, your data, your choice of storage. AI-powered answers about everything you own.

Ask your AI assistant natural language questions about everything you own — appliances, furniture, subscriptions, warranties, manuals, receipts, and more. Your data stays on your own device.

**Website:** [allourthings.io](https://allourthings.io)

## Packages

| Package | Description |
|---|---|
| [`packages/mcp-server`](./packages/mcp-server) | TypeScript MCP server — the core of the system |
| [`packages/website`](./packages/website) | Astro static site — allourthings.io |

---

## Platform support

| Platform | AI assistant | Add / browse inventory |
|---|---|---|
| macOS / Windows / Linux | ✅ Via Claude Desktop + MCP server | ✅ |
| iOS | 🔜 iOS app coming (Epic 6) | 🔜 iOS app coming |
| Android | 🔜 Planned (Epic 9) | 🔜 Planned |

The MCP server requires a desktop MCP client (Claude Desktop, Cursor, etc.). Mobile AI assistant access depends on MCP support arriving in mobile clients — the iOS app will handle add/browse in the meantime.

---

## Quick start

> **Desktop only.** Requires macOS, Windows, or Linux with [Claude Desktop](https://claude.ai/download) or another MCP-compatible client.

### 1. Add to Claude Desktop

Edit `~/Library/Application Support/Claude/claude_desktop_config.json` (macOS) or `%APPDATA%\Claude\claude_desktop_config.json` (Windows):

```json
{
  "mcpServers": {
    "allourthings": {
      "command": "npx",
      "args": ["-y", "@allourthings/mcp-server", "--data-dir", "~/Documents/AllOurThings"]
    }
  }
}
```

Restart Claude Desktop. Your inventory vault will be created automatically on first use.

### 2. Start asking questions

- *"Add my Bosch washing machine, bought from John Lewis for £649 in January 2024 with a 2-year warranty"*
- *"What appliances do I own?"*
- *"What's in the kitchen?"*
- *"When does my TV warranty expire?"*
- *"Search for anything Samsung"*
- *"How much have I spent on electronics?"*

---

## How it works

The MCP server exposes your inventory to any MCP-compatible AI client via six tools:

| Tool | Description |
|---|---|
| `add_item` | Add a new item to your inventory |
| `get_item` | Retrieve an item by ID or name |
| `list_items` | List all items, optionally filtered by category, location, or tags |
| `update_item` | Update fields on an existing item |
| `delete_item` | Delete an item by ID |
| `search_items` | Full-text search across all item fields |

---

## Data

### Vault structure

Your inventory lives in a **vault** — a plain directory on your filesystem. Each item gets its own folder:

```
~/Documents/AllOurThings/
  items/
    dyson-v15-detect-a1b2c3d4/
      item.json
      manual.pdf
      receipt.jpg
    samsung-65-qled-tv-b5c6d7e8/
      item.json
      warranty.pdf
```

Attachments (manuals, receipts, photos) sit alongside the item JSON. You can browse and edit the vault directly in Finder or File Explorer.

### Item schema

Every item has required fields (`id`, `name`, `created_at`, `updated_at`) and well-known optional fields:

`category` `brand` `model` `purchase_date` `purchase_price` `currency` `warranty_expires` `retailer` `location` `features` `notes` `tags` `attachments`

The `attachments` field links PDFs and images stored in the item's folder:

```json
{
  "attachments": [
    { "filename": "manual.pdf",  "type": "manual"   },
    { "filename": "receipt.jpg", "type": "receipt"  },
    { "filename": "photo.jpg",   "type": "photo"    }
  ]
}
```

You can also add any custom fields you like — they are preserved as-is.

### Configuration

| Method | Example |
|---|---|
| `--data-dir` arg *(recommended)* | `--data-dir ~/Documents/AllOurThings` |
| `ALLOURTHINGS_DATA_DIR` env var | `ALLOURTHINGS_DATA_DIR=~/Documents/AllOurThings` |
| Default | `~/Documents/AllOurThings` |

The `--data-dir` arg is the recommended approach — it's visible directly in your MCP client config.

---

## Development

### Prerequisites

- [Bun](https://bun.sh) — `brew install bun`
- [Task](https://taskfile.dev) — `brew install go-task`

### Install dependencies

```bash
bun install
```

### Tasks

| Task | Description |
|---|---|
| `task dev` | Seed vault + open MCP Inspector — fastest way to test |
| `task test:run` | Run automated tests |
| `task seed` | Append test items to dev vault |
| `task seed:reset` | Clear dev vault and re-seed |
| `task inspect` | Open MCP Inspector (dev mode, no build required) |
| `task inspect:prod` | Build, then open MCP Inspector against dist |
| `task build` | Compile MCP server to dist/ |
| `task typecheck` | Run TypeScript type checking |
| `task clean` | Remove dist/ |
| `task clean:vault` | Delete local dev vault |
| `task website:dev` | Start website dev server |
| `task website:build` | Build website for production |
| `task website:deploy` | Build and deploy to Cloudflare Pages |

All tasks use `./dev-vault` by default. Override with `DATA_DIR=/your/path task <command>`.
