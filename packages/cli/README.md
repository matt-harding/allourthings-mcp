# @allourthings/cli

> Manage your personal inventory from the terminal.

A CLI for [AllOurThings](https://allourthings.io) — catalog everything you own and query it from the command line. Works standalone, no AI client required.

## Install

```bash
# Run without installing
npx @allourthings/cli list

# Or install globally
npm install -g @allourthings/cli
```

## Commands

```bash
allourthings search <query>                               # full-text search
allourthings list [--category <c>] [-l <loc>] [-t <tag>] # list, optionally filtered
allourthings get <id-or-name>                             # full item detail
allourthings add <name> [options]                         # add an item
allourthings update <id> [options]                        # update item fields
allourthings delete <id>                                  # delete an item
```

**Attachments:**

```bash
allourthings attach add <item-id> <file>      # attach a local file
allourthings attach url <item-id> <url>       # download and attach from URL
allourthings attach get <item-id> <filename>  # save attachment to disk
allourthings attach rm  <item-id> <filename>  # delete attachment
```

## Options

**`add` and `update`:**

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
    --serial <serial>         serial number
-t, --tag <tag...>            repeatable
-n, --notes <notes>
    --set key=value           custom fields (update only, repeatable)
```

**Global:**

```
--data-dir <path>    inventory data directory (default: ~/Documents/AllOurThings)
--json               output raw JSON — for scripting and agent use
```

**Data directory:** defaults to `~/Documents/AllOurThings`. Override with `--data-dir` per command, or set once in your shell profile to avoid repeating it:

```sh
export ALLOURTHINGS_DATA_DIR=~/Dropbox/AllOurThings
```

The directory is created automatically on first write. Read commands return empty results against a missing directory rather than erroring.

## Examples

```bash
# Add an item
allourthings add "Bosch Washing Machine" \
  --brand Bosch --model "WGG244A9GB" \
  --category appliance --location kitchen \
  --purchase-date 2024-01-15 --price 649 --currency GBP \
  --warranty 2026-01-15 --retailer "John Lewis"

# Search
allourthings search "dishwasher"

# Get full detail
allourthings get "Bosch"

# Filter by category
allourthings list --category appliance

# Attach a manual
allourthings attach add 6164c373 ~/Downloads/manual.pdf --label "User manual"

# Attach from URL
allourthings attach url 6164c373 https://example.com/manual.pdf --label "User manual"

# Pipe to jq
allourthings search "warranty" --json | jq '[.[] | {name, warranty_expires}]'

# Use a different vault
allourthings --data-dir ~/Dropbox/AllOurThings list
```

## Data

Your inventory lives in a **vault** — a plain directory on your filesystem. Each item gets its own folder:

```
~/Documents/AllOurThings/
  items/
    bosch-washing-machine-6164c373/
      item.json
      manual.pdf
      receipt.jpg
```

The vault is plain files — browse it in Finder, back it up with Time Machine, or sync with iCloud, Dropbox, or any tool you like.

## Related

- [`@allourthings/mcp-server`](https://www.npmjs.com/package/@allourthings/mcp-server) — connect your inventory to Claude Desktop via MCP
- [allourthings.io](https://allourthings.io)

---

MIT
