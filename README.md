# AllOurThings

> Your things, understood by AI.

AllOurThings is an inventory system that works the way you do. Catalog anything you like from your home appliances to your Pokémon cards — then ask plain-English questions and get instant answers.

**Website:** [allourthings.io](https://allourthings.io)

## Packages

| Package | npm | Description |
|---|---|---|
| [`packages/mcp-server`](./packages/mcp-server) | [`@allourthings/mcp-server`](https://www.npmjs.com/package/@allourthings/mcp-server) | MCP server — connects your inventory to Claude Desktop and other MCP clients |
| [`packages/cli`](./packages/cli) | [`@allourthings/cli`](https://www.npmjs.com/package/@allourthings/cli) | CLI — manage your inventory from the terminal |

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

The MCP server exposes your inventory to any MCP-compatible AI client via 10 tools:

| Tool | Description |
|---|---|
| `add_item` | Add a new item to your inventory |
| `get_item` | Retrieve an item by ID or name |
| `list_items` | List all items, optionally filtered by category, location, or tags |
| `update_item` | Update fields on an existing item |
| `delete_item` | Delete an item by ID |
| `search_items` | Full-text search across all item fields |
| `add_attachment` | Attach a file (manual, receipt, photo, warranty) to an item |
| `get_attachment` | Retrieve an attachment as base64 |
| `delete_attachment` | Remove an attachment from an item |
| `attach_from_url` | Download a file from a URL and attach it to an item |

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


---

## CLI

A standalone terminal tool for power users and scripting. Works on macOS, Windows, and Linux. No AI client required.

```bash
# Run without installing
npx @allourthings/cli list

# Or install globally
npm install -g @allourthings/cli
```


### Commands

```bash
allourthings search <query>                          # full-text search across all fields
allourthings list [--category <c>] [-l <loc>] [-t <tag>]  # list items, optionally filtered
allourthings get <id-or-name>                        # show full item detail
allourthings add <name> [options]                    # add a new item
allourthings update <id> [options]                   # update item fields
allourthings delete <id>                             # delete an item (prompts for confirmation)
```

**Attachment management:**

```bash
allourthings attach add <item-id> <file>             # attach a local file to an item
allourthings attach url <item-id> <url>              # download a file and attach it
allourthings attach get <item-id> <filename>         # save an attachment to disk
allourthings attach rm  <item-id> <filename>         # delete an attachment
```

**`add` and `update` options:**

```
-c, --category <category>
-b, --brand <brand>
-m, --model <model>
    --purchase-date <date>    ISO date, e.g. 2024-01-15
    --price <price>
    --currency <currency>     e.g. GBP, USD
    --warranty <date>         warranty expiry ISO date
    --retailer <retailer>
-l, --location <location>
    --serial <serial>
-t, --tag <tag...>            repeatable
-n, --notes <notes>
    --set key=value           custom/extra fields (update only, repeatable)
```

**Global options:**

```
--data-dir <path>    path to inventory data directory (default: ~/Documents/AllOurThings)
--json               output raw JSON — useful for scripting and agent use
```

**Data directory:** defaults to `~/Documents/AllOurThings` on all platforms. Created automatically on first write — no setup required. Read commands (`list`, `search`, `get`) return empty results against a missing directory rather than erroring.

### Examples

```bash
# Add an item
allourthings add "Bosch Washing Machine" --brand Bosch --model "WGG244A9GB" \
  --category appliance --location kitchen \
  --purchase-date 2024-01-15 --price 649 --currency GBP \
  --warranty 2026-01-15 --retailer "John Lewis"

# Search and pipe to jq
allourthings search "warranty" --json | jq '[.[] | {name, warranty_expires}]'

# Attach a manual
allourthings attach add 6164c373 ~/Downloads/bosch-manual.pdf --label "User manual"

# Update a field
allourthings update 6164c373 --warranty 2027-01-15

# Use a custom data directory
allourthings --data-dir ~/Dropbox/AllOurThings list
```

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
| `task dev:mcp` | Start MCP server in watch mode (stdio) |
| `task test:run` | Run automated tests |
| `task seed` | Append test items to dev vault |
| `task seed:reset` | Clear dev vault and re-seed |
| `task inspect` | Open MCP Inspector (dev mode, no build required) |
| `task inspect:prod` | Build, then open MCP Inspector against compiled dist |
| `task build` | Compile MCP server to dist/ |
| `task build:cli` | Compile CLI to dist/ |
| `task cli -- <args>` | Run CLI from source against dev vault, e.g. `task cli -- list` |
| `task typecheck` | Run TypeScript type checking |
| `task clean` | Remove dist/ |
| `task clean:vault` | Delete local dev vault |

All tasks use `./dev-vault` by default. Override with `DATA_DIR=/your/path task <command>`.

---

## License

MIT — see [LICENSE](./LICENSE).
