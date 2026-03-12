# All Our Things — Claude Context

AI-powered household inventory system. Users ask natural language questions about everything they own — appliances, warranties, spending, manuals, etc. The AI talks to a local MCP server; data stays on the user's own storage.

## Monorepo structure

```
packages/
  mcp-server/       # TypeScript MCP server — the only package right now
    src/
      index.ts      # Entrypoint — wires backend + transport
      server.ts     # MCP server, tool registry, request handlers
      schema.ts     # Zod item schema (passthrough for custom fields)
      backends/
        interface.ts    # Backend interface — all backends must implement this
        filesystem.ts   # Current only backend — single JSON catalog file
      tools/
        add-item.ts
        get-item.ts
        list-items.ts
        update-item.ts
        delete-item.ts
        search-items.ts
```

## Tech stack

- **Runtime:** Bun (use `bun` not `node`/`npm`)
- **Language:** TypeScript (ESM, `.js` extensions in imports)
- **MCP SDK:** `@modelcontextprotocol/sdk`
- **Validation:** Zod + `zod-to-json-schema` for tool input schemas
- **Package manager:** Bun workspaces

## Key commands

All from `packages/mcp-server/`:

```bash
bun run dev        # Watch mode — starts server over stdio
bun run build      # Compile to dist/
bun run typecheck  # tsc --noEmit
```

Test without a full AI client:
```bash
npx @modelcontextprotocol/inspector bun packages/mcp-server/src/index.ts
```

## Architecture

### Backend interface pattern

`src/backends/interface.ts` defines a `Backend` interface. All storage backends implement this. Currently only `FilesystemBackend` exists. The Notion backend (Epic 3) will implement the same interface.

When adding a new backend: implement `Backend`, add auto-detection logic to `index.ts` (if `NOTION_TOKEN` env var present → Notion backend, else → filesystem).

### Storage

Default catalog path: `~/Library/Mobile Documents/com~apple~CloudDocs/AllOurThings/catalog.json` (iCloud Drive).

Override with `CATALOG_PATH` env var.

The filesystem backend stores all items as a single JSON array. On every write it loads the full array, mutates, and saves. Fine for personal inventory sizes.

### Item schema

Defined in `schema.ts` using Zod. Required fields: `id`, `name`, `created_at`, `updated_at`. Well-known optional fields: `category`, `brand`, `model`, `purchase_date`, `purchase_price`, `currency`, `warranty_expires`, `retailer`, `location`, `features`, `notes`, `tags`, `manual_ref`, `images`.

Schema uses `.passthrough()` — unknown custom fields are preserved as-is. This is intentional and important.

### Adding a new tool

1. Create `src/tools/my-tool.ts` — export an input schema (Zod) and a handler function
2. Register it in `server.ts` — add to `ListToolsRequestSchema` handler and `CallToolRequestSchema` switch

## Product backlog (Notion)

Backlog lives in the **Matt Brain** Notion workspace: [Product Backlog database](https://www.notion.so/a4be21b5abc04759aee5025f53c544fa)

Fields: Story, Epic, Phase, Priority (Must/Should/Could), Size (S/M/L/XL/Ongoing), Notes.

### Epics and current status

| Epic | Phase | Status |
|---|---|---|
| 1 — MCP Server MVP | 1 | Largely built (CRUD tools + filesystem backend done) |
| 2 — Publish & Distribute | 1 | Not started (npm publish, MCP Registry) |
| 2.5 — OpenClaw Skill | 1–3 | Not started (SKILL.md, ClawHub publish, cron alerts) |
| 3 — Notion Backend | 2 | Not started |
| 4 — MCP App UIs | 3 | Not started (Browse UI, Dashboard UI) |
| 5 — Advanced Tools | 3 | Not started (get_spending, search_manuals, prompts) |
| 6 — iOS App | 4 | **Removed from codebase** (commit: "Remove iOS/Swift app, keep MCP server only") — backlog items may need archiving |
| 7 — Website & Marketing | 2 | Not started (alloutthings.io Astro site, docs) |
| 8 — Monetisation | 5 | Not started (license keys via LemonSqueezy/Gumroad, £9–15 one-time) |

### Upcoming priorities (Phase 1 remaining)

- Publish to npm as `@alloutthings/mcp-server`
- Create `server.json` and publish to MCP Registry
- Write `SKILL.md` + publish to ClawHub marketplace

### Phase 2 next

- Build Notion template database matching item schema
- Implement Notion backend adapter (`@notionhq/client`)
- Backend auto-detection (`NOTION_TOKEN` → Notion, else → filesystem)
- alloutthings.io landing page (Astro)
- Setup documentation (per backend, per MCP client)

## Conventions

- Use Bun APIs over Node where available
- Zod for all input validation — never trust raw tool arguments
- Preserve `.passthrough()` on schemas — custom fields must survive round-trips
- `deleteItem` currently hard-deletes — backlog note suggests soft-delete (.trash folder) as a future improvement
- No tests yet — use MCP Inspector for manual testing

## Open questions / decisions needed

- iOS App (Epic 6): still in backlog but removed from codebase — confirm whether to archive or defer
- `search_manuals` tool assumes manuals are attached to items (`manual_ref` field) — no story yet for how users attach/upload manuals
- `deleteItem` is hard-delete in current implementation despite backlog note suggesting soft-delete
