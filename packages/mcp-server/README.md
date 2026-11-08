# @allourthings/mcp-server

> AI-powered household inventory, on your own storage.

An [MCP server](https://modelcontextprotocol.io) that gives your AI assistant natural language access to everything you own — appliances, furniture, subscriptions, warranties, manuals, receipts, and more. Your data stays on your own device.

## Requirements

**Desktop only** — macOS, Windows, or Linux with [Claude Desktop](https://claude.ai/download) or another MCP-compatible client. The MCP server runs as a local process and needs [Node.js](https://nodejs.org) 20 or later (for `npx`).

## Setup

First choose the folder that holds your inventory. It must already exist: create an empty folder such as `~/Documents/AllOurThings`, or run `npx @allourthings/cli init`, which creates and remembers it. If you use the AllOurThings iOS app, use the same folder it uses (e.g. in iCloud Drive).

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

Restart Claude Desktop.

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

| Tool | Description | Access |
|---|---|---|
| `search_items` | Ranked search by words: items containing any query word are returned, best match first, and items matching every word are marked. English plurals and accents are handled; synonyms and typos are not. Optional `limit` (default 20, max 100) | Read |
| `list_items` | List items, optionally filtered by `category`, `subcategory` or `tags` (all must match) | Read |
| `get_item` | Get an item by ID or name. If a name matches several items, the error lists their IDs | Read |
| `get_item_fields` | List the field names in use across your catalog | Read |
| `list_categories` | Categories with their subcategories, and tags, each with item counts | Read |
| `get_attachment` | Get an attachment: images as images, PDFs and other files as embedded resources, text files as text, after a one-line summary. Files over 10 MB return the summary only | Read |
| `add_item` | Add a new item. Names must be unique; custom fields are kept as-is | Write |
| `update_item` | Update fields on an item. Set a field to `null` to clear it | Write, destructive |
| `delete_item` | Delete an item and its attachments | Destructive |
| `add_attachment` | Attach a file: `item_id`, `filename`, `kind`, `data_base64`, optional `label` | Write |
| `attach_from_url` | Download a file from the public internet and attach it: `item_id`, `url`, `kind`, optional `filename` and `label` | Write, internet |
| `delete_attachment` | Remove an attachment from an item | Destructive |

`kind` is one of `manual`, `receipt`, `photo`, `warranty` or `other`. If `attach_from_url` has no `filename`, it uses the server's `Content-Disposition` filename, or else the last part of the final URL.

Each tool declares its access as MCP annotations (`readOnlyHint`, `destructiveHint`, `idempotentHint`, `openWorldHint`), so clients can ask you before changing, deleting or downloading. The server also sends the assistant short usage guidelines when it connects, e.g. to confirm before deleting and never to invent item IDs.

**Attachments never overwrite.** `add_attachment` and `attach_from_url` refuse a filename the item already has (ignoring case). To replace a file, delete it with `delete_attachment` and add it again.

**Downloads.** `attach_from_url` only fetches public `http` and `https` URLs:

- Addresses on your own machine or network are refused: loopback, private, link-local (including cloud metadata), carrier-grade NAT, multicast and reserved ranges, for IPv4 and IPv6. Every address a hostname resolves to is checked.
- Redirects are followed one at a time (at most 5), and each hop is checked again.
- Files are limited to 50 MB, enforced while downloading, with a 30-second timeout. HTML pages are rejected because they're usually a product page, not the file.
- Only the downloaded file is stored, in your vault.

Known limitation: the address is checked before connecting, so a hostname whose DNS changes in between (DNS rebinding) could still reach a local address.

**Errors.** Any failure — invalid or unknown arguments, an item that doesn't exist, a duplicate name, an invalid date — returns a result with `isError: true` and a message starting `Error: `. `get_item` for something that doesn't exist is not an error; it says no item was found.

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

If none is set, the server exits with a message explaining how to choose a vault. If the folder doesn't exist, the server exits and prints the path, rather than creating a mistyped folder. `--help` and `--version` print and exit.

A local query cache is kept outside the vault, in `~/Library/Caches/allourthings` (macOS), `%LOCALAPPDATA%\allourthings` (Windows) or `~/.cache/allourthings` (Linux). It holds the search index and is refreshed from the vault before lists and searches, so changes from the iOS app or other tools show up automatically. It is safe to delete.

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
