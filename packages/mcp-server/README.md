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
| `add_item` | Add a new item. Names must be unique; custom fields are kept as-is |
| `get_item` | Get an item by ID or name. If a name matches several items, the error lists their IDs |
| `list_items` | List items, optionally filtered by `category`, `subcategory` or `tags` (all must match) |
| `update_item` | Update fields on an item. Set a field to `null` to clear it |
| `delete_item` | Delete an item by ID |
| `search_items` | Search field values (case-insensitive); every word in the query must match |
| `get_item_fields` | List the field names in use across your catalog |
| `add_attachment` | Attach a file: `item_id`, `filename`, `kind`, `data_base64`, optional `label` |
| `attach_from_url` | Download a file and attach it: `item_id`, `url`, `kind`, optional `filename` and `label` |
| `get_attachment` | Get an attachment's contents as base64 |
| `delete_attachment` | Remove an attachment from an item |

`kind` is one of `manual`, `receipt`, `photo`, `warranty` or `other`. If `attach_from_url` has no `filename`, it uses the server's `Content-Disposition` filename, or else the last part of the final URL.

**Errors.** Any failure — invalid or unknown arguments, an item that doesn't exist, a duplicate name, an invalid date — returns a result with `isError: true` and a message describing the problem.

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

The server looks for your vault in this order:

1. `--data-dir <path>` in your MCP client config
2. the `ALLOURTHINGS_DATA_DIR` environment variable
3. the folder saved by [`allourthings init`](https://www.npmjs.com/package/@allourthings/cli)

If none is set, the server exits with an error explaining how to configure one. `--help` and `--version` print and exit.

A local query cache is kept outside the vault, in `~/Library/Caches/allourthings` (macOS), `%LOCALAPPDATA%\allourthings` (Windows) or `~/.cache/allourthings` (Linux). It is refreshed from the vault before lists and searches, so changes from the iOS app or other tools show up automatically. It is safe to delete.

## Item schema

Required fields: `id`, `name`, `created_at`, `updated_at`

Well-known optional fields: `category` `subcategory` `brand` `model` `purchase_date` `purchase_price` `currency` `warranty_expires` `retailer` `location` `features` `notes` `tags` `attachments`

Custom fields are preserved as-is — add anything you like.

Rules enforced on every write:

- `name` must not be empty and must be unique (ignoring case and surrounding spaces)
- `purchase_date` and `warranty_expires` must be `YYYY-MM-DD` (or a full ISO 8601 timestamp)
- `purchase_price` must be a non-negative number
- `id`, `created_at`, `updated_at` and `attachments` are managed for you and can't be set directly

---

[allourthings.io](https://allourthings.io)
