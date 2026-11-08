# @allourthings/cli

> Manage your personal inventory from the terminal.

A CLI for [AllOurThings](https://allourthings.io) — catalog everything you own and query it from the command line. Works standalone, no AI client required.

## Install

Requires [Node.js](https://nodejs.org) 20 or later.

```bash
# Run without installing
npx @allourthings/cli list

# Or install globally
npm install -g @allourthings/cli
```

## Commands

```bash
allourthings init [path]                                  # choose your vault folder (run once)
allourthings search <query> [-n <limit>]                  # ranked search: any word matches, best first
allourthings list [-c <category>] [-s <subcategory>] [-t <tag>]  # list, optionally filtered
allourthings get <id-or-name>                             # full item detail
allourthings add <name> [options]                         # add an item
allourthings update <id> [options]                        # update item fields
allourthings delete <id> [-y]                             # delete an item (asks to confirm unless -y)
allourthings fields                                       # field names in use across your catalog
allourthings categories                                   # categories, subcategories and tags with counts
```

`get` accepts an ID or a name. If a name matches more than one item, it prints an error listing their IDs.

`search` ranks items by how well they match: names count most, then brand and model, then category, subcategory and tags, then notes, custom fields and attachment names. English plurals and accents are handled (`fridges` finds "Wine Fridge", `pokemon` finds "Pokémon"); synonyms and typos are not.

**Attachments:**

```bash
allourthings attach add <item-id> <file> [-k <kind>] [--label <label>] [--replace]  # attach a local file
allourthings attach url <item-id> <url> [-k <kind>] [-f <filename>] [--label <label>] [--replace]
allourthings attach get <item-id> <filename> [-o <path>]  # save to disk; -o - writes to stdout
allourthings attach rm  <item-id> <filename>              # delete an attachment
```

`kind` is one of `manual`, `receipt`, `photo`, `warranty` or `other`, and is guessed from the filename if omitted. `attach url` takes the filename from the server's `Content-Disposition` header or the final URL unless you pass `-f`.

`attach add` and `attach url` refuse a filename the item already has (ignoring case) unless you pass `--replace`.

`attach url` only downloads public `http`/`https` URLs. Addresses on your own machine or network (loopback, private, link-local, carrier-grade NAT) are refused, every redirect is checked again (at most 5), and files are limited to 50 MB with a 30-second timeout.

## Options

**`add` and `update`:**

```
-c, --category <category>
-s, --subcategory <subcategory>
-b, --brand <brand>
-m, --model <model>
    --purchase-date <date>    YYYY-MM-DD
    --price <price>           non-negative number, e.g. 649 or 12.99
    --currency <currency>     e.g. GBP, USD
    --warranty <date>         warranty expiry, YYYY-MM-DD
    --retailer <retailer>
-l, --location <location>
    --serial <serial>         serial number
-t, --tag <tag...>            repeatable
-n, --notes <notes>
```

**`update` only:**

```
    --name <name>             rename the item (names must be unique)
    --set <key=value...>      set any field; tags and features take comma-separated lists
    --unset <field...>        remove fields
```

On `update`, an empty value clears a field: `--notes ""` and `--set serial_number=` both remove it.

**Global:**

```
--data-dir <path>    vault folder (overrides ALLOURTHINGS_DATA_DIR and the folder saved by init)
--json               JSON output for scripting; errors go to stderr as {"error": "..."}
```

Errors print a single `error: ...` line and exit with status 1.

**Vault location:** run `allourthings init` once to choose a folder (it suggests `~/Documents/AllOurThings`). The choice is saved to `~/Library/Application Support/allourthings/config.json` (macOS), `%APPDATA%\allourthings\config.json` (Windows) or `~/.config/allourthings/config.json` (Linux), and the MCP server reads the same file. To override it, set `ALLOURTHINGS_DATA_DIR` or pass `--data-dir`:

```sh
export ALLOURTHINGS_DATA_DIR=~/Dropbox/AllOurThings
```

The folder is created on first write. Read commands return empty results for a missing folder rather than erroring. (The MCP server is stricter: it refuses to start if its folder doesn't exist.)

## Examples

```bash
# Add an item
allourthings add "Bosch Washing Machine" \
  --brand Bosch --model "WGG244A9GB" \
  --category appliance --location kitchen \
  --purchase-date 2024-01-15 --price 649 --currency GBP \
  --warranty 2026-01-15 --retailer "John Lewis"

# Search (best matches first; --limit caps the results)
allourthings search "dishwasher"
allourthings search "kitchen appliances" --limit 5

# See how your catalog is organised
allourthings categories

# Get full detail (by name, if it's unambiguous)
allourthings get "Bosch Washing Machine"

# Filter by category
allourthings list --category appliance

# Attach a manual
allourthings attach add 6164c373 ~/Downloads/manual.pdf --label "User manual"

# Attach from URL
allourthings attach url 6164c373 https://example.com/manual.pdf --label "User manual"

# Clear fields
allourthings update 6164c373 --unset notes serial_number

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
