#!/usr/bin/env node
import { createRequire } from "module";
import { readFileSync, writeFileSync } from "fs";
import { homedir } from "os";
import { join, basename } from "path";
import { Command } from "commander";
import { formatItem, formatItems, out, type Item } from "./format.js";

// ── Backend ──────────────────────────────────────────────────────────────────

const require = createRequire(import.meta.url);
const { JsCatalogStore } = require("@allourthings/core");
const { version } = require("../package.json");

function resolveDataDir(): string {
  const argv = process.argv;
  const i = argv.indexOf("--data-dir");
  if (i !== -1 && argv[i + 1]) return expandTilde(argv[i + 1]);
  if (process.env.ALLOURTHINGS_DATA_DIR) return expandTilde(process.env.ALLOURTHINGS_DATA_DIR);
  return join(homedir(), "Documents", "AllOurThings");
}

function expandTilde(p: string): string {
  return p === "~" || p.startsWith("~/") ? join(homedir(), p.slice(2)) : p;
}

function makeStore() {
  return new JsCatalogStore(resolveDataDir());
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function inferKind(filename: string): string {
  const lower = filename.toLowerCase();
  if (lower.includes("manual") || lower.includes("guide")) return "manual";
  if (lower.includes("receipt") || lower.includes("invoice")) return "receipt";
  if (lower.includes("warrant")) return "warranty";
  if (/\.(jpg|jpeg|png|gif|webp|heic)$/.test(lower)) return "photo";
  return "other";
}

function die(msg: string): never {
  process.stderr.write(`error: ${msg}\n`);
  process.exit(1);
}

// ── Program ───────────────────────────────────────────────────────────────────

const program = new Command();

program
  .name("allourthings")
  .description("AllOurThings — manage your personal inventory from the terminal.")
  .version(version)
  .option("--data-dir <path>", "path to inventory data directory (default: ~/Documents/AllOurThings)")
  .option("--json", "output raw JSON");

// ── search ────────────────────────────────────────────────────────────────────

program
  .command("search <query>")
  .description("full-text search across all item fields")
  .action((query: string) => {
    const json = !!program.opts().json;
    const store = makeStore();
    const items: Item[] = store.searchItems(query);
    out(json, formatItems(items, `${items.length} result${items.length === 1 ? "" : "s"} for "${query}"`), items);
  });

// ── list ──────────────────────────────────────────────────────────────────────

program
  .command("list")
  .description("list items, optionally filtered")
  .option("-c, --category <category>", "filter by category")
  .option("-l, --location <location>", "filter by location")
  .option("-t, --tag <tag...>", "filter by tag (repeatable, all must match)")
  .action((opts: { category?: string; location?: string; tag?: string[] }) => {
    const json = !!program.opts().json;
    const store = makeStore();
    const filter = {
      ...(opts.category && { category: opts.category }),
      ...(opts.location && { location: opts.location }),
      ...(opts.tag?.length && { tags: opts.tag }),
    };
    const items: Item[] = store.listItems(Object.keys(filter).length ? filter : null);
    out(json, formatItems(items), items);
  });

// ── get ───────────────────────────────────────────────────────────────────────

program
  .command("get <id-or-name>")
  .description("get a single item by ID or name")
  .action((idOrName: string) => {
    const json = !!program.opts().json;
    const store = makeStore();
    const item: Item | null = store.getItem(idOrName);
    if (!item) die(`no item found: ${idOrName}`);
    out(json, formatItem(item), item);
  });

// ── add ───────────────────────────────────────────────────────────────────────

program
  .command("add <name>")
  .description("add a new item to the inventory")
  .option("-c, --category <category>")
  .option("-b, --brand <brand>")
  .option("-m, --model <model>")
  .option("--purchase-date <date>", "ISO date, e.g. 2024-01-15")
  .option("--price <price>", "purchase price (numeric)")
  .option("--currency <currency>", "currency code, e.g. GBP")
  .option("--warranty <date>", "warranty expiry ISO date")
  .option("--retailer <retailer>")
  .option("-l, --location <location>")
  .option("--serial <serial>", "serial number")
  .option("-t, --tag <tag...>", "tag (repeatable)")
  .option("-n, --notes <notes>")
  .action((name: string, opts: Record<string, unknown>) => {
    const json = !!program.opts().json;
    const store = makeStore();
    const newItem: Record<string, unknown> = { name };
    if (opts.category) newItem.category = opts.category;
    if (opts.brand) newItem.brand = opts.brand;
    if (opts.model) newItem.model = opts.model;
    if (opts.purchaseDate) newItem.purchase_date = opts.purchaseDate;
    if (opts.price) {
      const n = Number(opts.price);
      if (isNaN(n)) die("--price must be a number");
      newItem.purchase_price = n;
    }
    if (opts.currency) newItem.currency = opts.currency;
    if (opts.warranty) newItem.warranty_expires = opts.warranty;
    if (opts.retailer) newItem.retailer = opts.retailer;
    if (opts.location) newItem.location = opts.location;
    if (opts.serial) newItem.serial_number = opts.serial;
    if (opts.tag) newItem.tags = opts.tag;
    if (opts.notes) newItem.notes = opts.notes;
    const item: Item = store.addItem(newItem);
    out(json, `Added: ${formatItem(item)}`, item);
  });

// ── update ────────────────────────────────────────────────────────────────────

program
  .command("update <id>")
  .description("update fields on an existing item")
  .option("--name <name>")
  .option("-c, --category <category>")
  .option("-b, --brand <brand>")
  .option("-m, --model <model>")
  .option("--purchase-date <date>")
  .option("--price <price>")
  .option("--currency <currency>")
  .option("--warranty <date>", "warranty expiry ISO date")
  .option("--retailer <retailer>")
  .option("-l, --location <location>")
  .option("--serial <serial>")
  .option("-t, --tag <tag...>")
  .option("-n, --notes <notes>")
  .option("--set <pair...>", "set a custom field: key=value (repeatable)")
  .action((id: string, opts: Record<string, unknown>) => {
    const json = !!program.opts().json;
    const store = makeStore();
    const updates: Record<string, unknown> = {};
    if (opts.name) updates.name = opts.name;
    if (opts.category) updates.category = opts.category;
    if (opts.brand) updates.brand = opts.brand;
    if (opts.model) updates.model = opts.model;
    if (opts.purchaseDate) updates.purchase_date = opts.purchaseDate;
    if (opts.price) {
      const n = Number(opts.price);
      if (isNaN(n)) die("--price must be a number");
      updates.purchase_price = n;
    }
    if (opts.currency) updates.currency = opts.currency;
    if (opts.warranty) updates.warranty_expires = opts.warranty;
    if (opts.retailer) updates.retailer = opts.retailer;
    if (opts.location) updates.location = opts.location;
    if (opts.serial) updates.serial_number = opts.serial;
    if (opts.tag) updates.tags = opts.tag;
    if (opts.notes) updates.notes = opts.notes;
    if (Array.isArray(opts.set)) {
      for (const pair of opts.set as string[]) {
        const eq = pair.indexOf("=");
        if (eq === -1) die(`--set requires key=value format, got: ${pair}`);
        updates[pair.slice(0, eq)] = pair.slice(eq + 1);
      }
    }
    if (Object.keys(updates).length === 0) die("no fields to update — provide at least one option");
    const item: Item | null = store.updateItem(id, updates);
    if (!item) die(`no item found with id: ${id}`);
    out(json, `Updated: ${formatItem(item)}`, item);
  });

// ── delete ────────────────────────────────────────────────────────────────────

program
  .command("delete <id>")
  .description("permanently delete an item by ID")
  .option("-y, --yes", "skip confirmation prompt")
  .action(async (id: string, opts: { yes?: boolean }) => {
    const json = !!program.opts().json;
    const store = makeStore();

    if (!opts.yes && !json) {
      process.stdout.write(`Delete item ${id}? This cannot be undone. [y/N] `);
      const line = await new Promise<string>((resolve) => {
        process.stdin.once("data", (d) => resolve(d.toString().trim()));
      });
      if (line.toLowerCase() !== "y") {
        process.stdout.write("Cancelled.\n");
        process.exit(0);
      }
    }

    const ok: boolean = store.deleteItem(id);
    if (!ok) die(`no item found with id: ${id}`);
    out(json, `Deleted item ${id}.`, { deleted: true, id });
  });

// ── attach ────────────────────────────────────────────────────────────────────

const attach = program.command("attach").description("manage item attachments");

attach
  .command("add <item-id> <file>")
  .description("attach a local file to an item")
  .option("-k, --kind <kind>", "manual | receipt | photo | warranty | other (inferred from filename if omitted)")
  .option("--label <label>", "human-readable label")
  .action((itemId: string, file: string, opts: { kind?: string; label?: string }) => {
    const json = !!program.opts().json;
    const store = makeStore();
    let data: Buffer;
    try {
      data = readFileSync(file);
    } catch {
      die(`cannot read file: ${file}`);
    }
    const filename = basename(file);
    const kind = opts.kind ?? inferKind(filename);
    const item: Item = store.addAttachment(itemId, filename, kind, data, opts.label ?? null);
    out(json, `Attached ${filename} to ${item.name} (${item.id}).`, item);
  });

attach
  .command("url <item-id> <url>")
  .description("download a file from a URL and attach it to an item")
  .option("-f, --filename <filename>", "filename to store as (inferred from URL if omitted)")
  .option("-k, --kind <kind>", "manual | receipt | photo | warranty | other")
  .option("--label <label>")
  .action(async (itemId: string, url: string, opts: { filename?: string; kind?: string; label?: string }) => {
    const json = !!program.opts().json;
    const store = makeStore();
    const TIMEOUT_MS = 30_000;
    const MAX_BYTES = 50 * 1024 * 1024;

    const abort = new AbortController();
    const timer = setTimeout(() => abort.abort(), TIMEOUT_MS);
    let response: Response;
    try {
      response = await fetch(url, { signal: abort.signal });
    } catch (err: unknown) {
      clearTimeout(timer);
      die(err instanceof Error && err.name === "AbortError"
        ? `download timed out after ${TIMEOUT_MS / 1000}s`
        : `network error: ${err instanceof Error ? err.message : String(err)}`);
    }
    clearTimeout(timer);

    if (!response.ok) die(`download failed: HTTP ${response.status} ${response.statusText}`);

    const contentType = response.headers.get("content-type") ?? "";
    if (contentType.startsWith("text/html")) die("URL returned an HTML page, not a file. Try finding a direct download link.");

    const buffer = Buffer.from(await response.arrayBuffer());
    if (buffer.byteLength > MAX_BYTES) die(`file too large (${Math.round(buffer.byteLength / 1024 / 1024)} MB — limit is 50 MB)`);

    const filename = opts.filename ?? (basename(new URL(url).pathname) || "attachment");
    const kind = opts.kind ?? inferKind(filename);
    const item: Item = store.addAttachment(itemId, filename, kind, buffer, opts.label ?? null);
    out(json, `Attached ${filename} to ${item.name} (${item.id}).`, item);
  });

attach
  .command("get <item-id> <filename>")
  .description("download an attachment to a local file")
  .option("-o, --output <path>", "output path (defaults to ./<filename>)")
  .action((itemId: string, filename: string, opts: { output?: string }) => {
    const store = makeStore();
    const data: Buffer = store.getAttachment(itemId, filename);
    if (!data) die(`attachment not found: ${filename} on item ${itemId}`);
    const dest = opts.output ?? basename(filename);
    writeFileSync(dest, data);
    process.stdout.write(`Saved to ${dest}\n`);
  });

attach
  .command("rm <item-id> <filename>")
  .description("delete an attachment from an item")
  .action((itemId: string, filename: string) => {
    const json = !!program.opts().json;
    const store = makeStore();
    const item: Item | null = store.deleteAttachment(itemId, filename);
    if (!item) die(`attachment not found: ${filename} on item ${itemId}`);
    out(json, `Deleted ${filename} from ${item.name} (${item.id}).`, item);
  });

// ── go ────────────────────────────────────────────────────────────────────────

program.parse();
