# @allourthings/mcp-server

> AI-powered household inventory, on your own storage.

An [MCP server](https://modelcontextprotocol.io) that gives your AI assistant natural language access to everything you own — appliances, furniture, subscriptions, warranties, manuals, receipts, and more. Your data stays on your own device.

## Requirements

**Desktop only** — macOS, Windows, or Linux with [Claude Desktop](https://claude.ai/download) or another MCP-compatible client. The MCP server runs as a local process.

## Setup

### Claude Desktop

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

Restart Claude Desktop. Your inventory vault is created automatically on first use.

### Other MCP clients

```json
{
  "command": "npx",
  "args": ["-y", "@allourthings/mcp-server", "--data-dir", "~/Documents/AllOurThings"]
}
```

## Usage

Once connected, ask your AI assistant things like:

- *"Add my Bosch washing machine, bought from John Lewis for £649 in January 2024 with a 2-year warranty"*
- *"What appliances do I own?"*
- *"What's in the kitchen?"*
- *"When does my TV warranty expire?"*
- *"Search for anything Samsung"*
- *"Find and attach the manual for my Dyson V15"*
- *"Attach this receipt to my MacBook"*

## Tools

| Tool | Description |
|---|---|
| `add_item` | Add a new item to your inventory |
| `get_item` | Retrieve an item by ID or name |
| `list_items` | List all items, optionally filtered by category, location, or tags |
| `update_item` | Update fields on an existing item |
| `delete_item` | Delete an item by ID |
| `search_items` | Full-text search across all item fields |
| `add_attachment` | Attach a file (manual, receipt, photo, warranty) to an item |
| `attach_from_url` | Download a file from a URL and attach it to an item |
| `get_attachment` | Retrieve an attachment's contents |
| `delete_attachment` | Remove an attachment from an item |

## Vault structure

Your inventory lives in a plain directory. Each item gets its own folder:

```
~/Documents/AllOurThings/
  items/
    dyson-v15-detect-a1b2c3d4/
      item.json
      manual.pdf
      receipt.jpg
    samsung-65-qled-tv-b5c6d7e8/
      item.json
```

Attachments (manuals, receipts, photos) sit alongside the item JSON. The vault is plain files — browse it in Finder, back it up with Time Machine, or sync it with any tool you like.

## Configuration

The `--data-dir` arg controls where your inventory is stored. It defaults to `~/Documents/AllOurThings` if omitted. To use a different location, update the path in your MCP client config:

```json
"args": ["-y", "@allourthings/mcp-server", "--data-dir", "/path/to/your/vault"]
```

## Item schema

Required fields: `id`, `name`, `created_at`, `updated_at`

Well-known optional fields: `category` `brand` `model` `purchase_date` `purchase_price` `currency` `warranty_expires` `retailer` `location` `features` `notes` `tags` `attachments`

Custom fields are preserved as-is — add anything you like.

---

[allourthings.io](https://allourthings.io)
