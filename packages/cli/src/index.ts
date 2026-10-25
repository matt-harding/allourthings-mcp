#!/usr/bin/env node
import { createRequire } from "module";
import { readFileSync, writeFileSync, mkdirSync, accessSync, existsSync, constants as fsConstants } from "fs";
import { createHash } from "crypto";
import { homedir, platform } from "os";
import { join, basename, dirname } from "path";
import { Command } from "commander";
import { formatItem, formatItems, out, type Item } from "./format.js";

// ── Config file ───────────────────────────────────────────────────────────────

function platformConfigPath(): string {
  if (platform() === "win32") {
    return join(process.env.APPDATA ?? join(homedir(), "AppData", "Roaming"), "allourthings", "config.json");
  }
  if (platform() === "darwin") {
    return join(homedir(), "Library", "Application Support", "allourthings", "config.json");
  }
  const xdg = process.env.XDG_CONFIG_HOME;
  return join(xdg ?? join(homedir(), ".config"), "allourthings", "config.json");
}

function readConfigFile(): string | null {
  try {
    const raw = readFileSync(platformConfigPath(), "utf8");
    const parsed = JSON.parse(raw) as unknown;
    if (
      parsed !== null &&
      typeof parsed === "object" &&
      "data_dir" in parsed &&
      typeof (parsed as Record<string, unknown>).data_dir === "string"
    ) {
      const dir = (parsed as { data_dir: string }).data_dir;
      return dir ? expandTilde(dir) : null;
    }
  } catch {
    // file missing or malformed — treat as unconfigured
  }
  return null;
}

// ── Backend ──────────────────────────────────────────────────────────────────

const require = createRequire(import.meta.url);
const { JsCatalogStore } = require("@allourthings/core");
const { version } = require("../package.json");

function resolveDataDir(): string {
  const argv = process.argv;
  const i = argv.indexOf("--data-dir");
  if (i !== -1 && argv[i + 1]) return expandTilde(argv[i + 1]);
  if (process.env.ALLOURTHINGS_DATA_DIR) return expandTilde(process.env.ALLOURTHINGS_DATA_DIR);
  const fromConfig = readConfigFile();
  if (fromConfig) return fromConfig;
  throw new Error(
    "No vault configured. Run `allourthings init` to set up, or set the ALLOURTHINGS_DATA_DIR environment variable."
  );
}

function expandTilde(p: string): string {
  return p === "~" || p.startsWith("~/") ? join(homedir(), p.slice(2)) : p;
}

function resolveCacheDir(dataDir: string): string {
  // Version the cache key so a cache written by an older native core cannot
  // prevent the CLI from discovering items stored by another client.
  const hash = createHash("sha256").update(`v2:${dataDir}`).digest("hex").slice(0, 16);
  const base = platform() === "darwin"
    ? join(homedir(), "Library", "Caches", "allourthings")
    : platform() === "win32"
    ? join(process.env.LOCALAPPDATA ?? join(homedir(), "AppData", "Local"), "allourthings")
    : join(process.env.XDG_CACHE_HOME ?? join(homedir(), ".cache"), "allourthings");
  return join(base, hash);
}

function makeStore() {
  let dataDir: string;
  try {
    dataDir = resolveDataDir();
  } catch (err) {
    return die(err instanceof Error ? err.message : String(err));
  }
  const store = new JsCatalogStore(dataDir, resolveCacheDir(dataDir));

  // The vault may have been changed by the iOS app or another MCP client.
  // Populate/synchronise the query cache before commands such as list, search,
  // and fields query it.
  try {
    store.refresh();
  } catch (err) {
    return die(`cannot refresh inventory cache: ${err instanceof Error ? err.message : String(err)}`);
  }

  return store;
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

// Read before commander parses so errors raised during parsing honour --json too.
const JSON_OUTPUT = process.argv.includes("--json");

function die(msg: string): never {
  process.stderr.write(JSON_OUTPUT ? JSON.stringify({ error: msg }) + "\n" : `error: ${msg}\n`);
  process.exit(1);
}

/** Resolves with the next line of stdin, or null if stdin ends first. */
function readLine(): Promise<string | null> {
  return new Promise((resolve) => {
    let buf = "";
    const finish = (line: string | null) => {
      process.stdin.off("data", onData);
      process.stdin.off("end", onEnd);
      process.stdin.pause();
      resolve(line === null ? null : line.trim());
    };
    const onData = (d: Buffer) => {
      buf += d.toString();
      const nl = buf.indexOf("\n");
      if (nl !== -1) finish(buf.slice(0, nl));
    };
    const onEnd = () => finish(buf.length ? buf : null);
    process.stdin.on("data", onData);
    process.stdin.once("end", onEnd);
    process.stdin.resume();
  });
}

async function confirm(prompt: string): Promise<boolean> {
  process.stdout.write(`${prompt} [y/N] `);
  const answer = await readLine();
  if (answer === null) die("no answer received; pass --yes to skip the prompt");
  return ["y", "yes"].includes(answer.toLowerCase());
}

function parsePrice(value: string): number {
  if (!/^\d+(\.\d+)?$/.test(value.trim())) {
    die(`price must be a non-negative decimal number such as 649 or 12.99 (got "${value}")`);
  }
  return Number(value);
}

const STRING_OPTIONS: Array<[option: string, flag: string, field: string]> = [
  ["category", "--category", "category"],
  ["subcategory", "--subcategory", "subcategory"],
  ["brand", "--brand", "brand"],
  ["model", "--model", "model"],
  ["purchaseDate", "--purchase-date", "purchase_date"],
  ["currency", "--currency", "currency"],
  ["warranty", "--warranty", "warranty_expires"],
  ["retailer", "--retailer", "retailer"],
  ["location", "--location", "location"],
  ["serial", "--serial", "serial_number"],
  ["notes", "--notes", "notes"],
];

/** Maps field options to item fields. On update an empty value clears the field (null). */
function collectFields(opts: Record<string, unknown>, mode: "add" | "update"): Record<string, unknown> {
  const fields: Record<string, unknown> = {};
  for (const [option, flag, field] of STRING_OPTIONS) {
    const value = opts[option] as string | undefined;
    if (value === undefined) continue;
    if (value === "") {
      if (mode === "add") die(`${flag} must not be empty`);
      fields[field] = null;
    } else {
      fields[field] = value;
    }
  }
  const price = opts.price as string | undefined;
  if (price !== undefined) {
    if (price === "" && mode === "add") die("--price must not be empty");
    fields.purchase_price = price === "" ? null : parsePrice(price);
  }
  if (opts.tag) fields.tags = opts.tag;
  return fields;
}

/** Parses `--set key=value`. Well-known typed fields are converted; an empty value clears the field. */
function parseSet(pair: string): [string, unknown] {
  const eq = pair.indexOf("=");
  const key = eq === -1 ? "" : pair.slice(0, eq).trim();
  if (!key) die(`--set requires key=value with a non-empty key, got: ${pair}`);
  const value = pair.slice(eq + 1);
  if (value === "") return [key, null];
  if (key === "purchase_price") return [key, parsePrice(value)];
  if (key === "tags" || key === "features") {
    return [key, value.split(",").map((s) => s.trim()).filter(Boolean)];
  }
  return [key, value];
}

function isPlainFilename(name: string): boolean {
  return name.length > 0 && name !== "." && name !== ".." && !/[\\/]/.test(name);
}

function safeDecode(s: string): string {
  try {
    return decodeURIComponent(s);
  } catch {
    return s;
  }
}

function inferUrlFilename(contentDisposition: string | null, finalUrl: string): string {
  if (contentDisposition) {
    const extended = /filename\*\s*=\s*([^']*)'[^']*'([^;]+)/i.exec(contentDisposition);
    const plain = /filename\s*=\s*("([^"]*)"|[^;]+)/i.exec(contentDisposition);
    const raw = extended
      ? safeDecode(extended[2].trim().replace(/^"|"$/g, ""))
      : plain ? (plain[2] ?? plain[1]).trim() : null;
    const name = raw ? basename(raw.replace(/\\/g, "/")) : "";
    if (isPlainFilename(name)) return name;
  }
  const fromUrl = basename(safeDecode(new URL(finalUrl).pathname));
  return isPlainFilename(fromUrl) ? fromUrl : "attachment";
}

// ── Program ───────────────────────────────────────────────────────────────────

const program = new Command();

program
  .name("allourthings")
  .description("AllOurThings — manage your personal inventory from the terminal.")
  .version(version)
  .option("--data-dir <path>", "path to the vault (overrides ALLOURTHINGS_DATA_DIR and the folder saved by `init`)")
  .option("--json", "output raw JSON (errors are written to stderr as {\"error\": ...})");

// ── search ─────────────────────────────────────────────────────────────────────────────────

program
  .command("search <query>")
  .description("search item field values; every word must match")
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
  .option("-s, --subcategory <subcategory>", "filter by subcategory")
  .option("-t, --tag <tag...>", "filter by tag (repeatable, all must match)")
  .action((opts: { category?: string; subcategory?: string; tag?: string[] }) => {
    const json = !!program.opts().json;
    const store = makeStore();
    const filter = {
      ...(opts.category && { category: opts.category }),
      ...(opts.subcategory && { subcategory: opts.subcategory }),
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
  .option("-s, --subcategory <subcategory>")
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
    const item: Item = store.addItem({ name, ...collectFields(opts, "add") });
    out(json, `Added: ${formatItem(item)}`, item);
  });

// ── update ────────────────────────────────────────────────────────────────────

program
  .command("update <id>")
  .description("update fields on an existing item")
  .option("--name <name>")
  .option("-c, --category <category>")
  .option("-s, --subcategory <subcategory>")
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
  .option("--set <pair...>", "set a custom field: key=value (repeatable; empty value clears it)")
  .option("--unset <field...>", "remove a field (repeatable)")
  .action((id: string, opts: Record<string, unknown>) => {
    const json = !!program.opts().json;
    const store = makeStore();
    const updates = collectFields(opts, "update");
    if (opts.name !== undefined) updates.name = opts.name;
    for (const pair of (opts.set as string[] | undefined) ?? []) {
      const [key, value] = parseSet(pair);
      updates[key] = value;
    }
    for (const field of (opts.unset as string[] | undefined) ?? []) updates[field] = null;
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
      if (!(await confirm(`Delete item ${id}? This cannot be undone.`))) die("cancelled");
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
  .option("-f, --filename <filename>", "filename to store as (from Content-Disposition or the URL if omitted)")
  .option("-k, --kind <kind>", "manual | receipt | photo | warranty | other")
  .option("--label <label>")
  .action(async (itemId: string, url: string, opts: { filename?: string; kind?: string; label?: string }) => {
    const json = !!program.opts().json;
    const store = makeStore();
    const TIMEOUT_MS = 30_000;
    const MAX_BYTES = 50 * 1024 * 1024;

    // Validate before downloading so a bad call never fetches the URL.
    if (opts.filename !== undefined && !isPlainFilename(opts.filename)) {
      die(`invalid filename: ${opts.filename}`);
    }
    const existing: Item | null = store.getItem(itemId);
    if (!existing || existing.id !== itemId) die(`no item found with id: ${itemId}`);

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

    const filename = opts.filename ?? inferUrlFilename(response.headers.get("content-disposition"), response.url || url);
    const kind = opts.kind ?? inferKind(filename);
    const item: Item = store.addAttachment(itemId, filename, kind, buffer, opts.label ?? null);
    out(json, `Attached ${filename} to ${item.name} (${item.id}).`, item);
  });

attach
  .command("get <item-id> <filename>")
  .description("download an attachment to a local file")
  .option("-o, --output <path>", "output path (defaults to ./<filename>; use - for stdout)")
  .action((itemId: string, filename: string, opts: { output?: string }) => {
    const json = !!program.opts().json;
    const store = makeStore();
    const data: Buffer = store.getAttachment(itemId, filename);
    if (opts.output === "-") {
      process.stdout.write(data);
      return;
    }
    const dest = opts.output ?? basename(filename);
    writeFileSync(dest, data);
    out(json, `Saved to ${dest}`, { saved: dest, bytes: data.length });
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

// ── fields ────────────────────────────────────────────────────────────────────

program
  .command("fields")
  .description("list all field names currently in use across your catalog")
  .action(() => {
    const json = !!program.opts().json;
    const store = makeStore();
    const fields: string[] = store.getItemFields();
    if (json) {
      out(json, "", fields);
    } else {
      if (fields.length === 0) {
        process.stdout.write("No items in catalog yet.\n");
      } else {
        process.stdout.write(`Fields in use:\n${fields.map((f) => `  ${f}`).join("\n")}\n`);
      }
    }
  });

// ── init ──────────────────────────────────────────────────────────────────────

program
  .command("init [path]")
  .description("configure the vault directory (writes platform config file)")
  .option("-y, --yes", "overwrite existing config without prompting")
  .action(async (pathArg: string | undefined, opts: { yes?: boolean }) => {
    const defaultDir = join(homedir(), "Documents", "AllOurThings");

    let vaultDir: string;
    if (pathArg) {
      vaultDir = expandTilde(pathArg);
    } else {
      process.stdout.write(`Vault directory [${defaultDir}]: `);
      const line = await readLine();
      vaultDir = line ? expandTilde(line) : defaultDir;
    }

    const configPath = platformConfigPath();

    if (!opts.yes && existsSync(configPath)) {
      const existing = readConfigFile();
      const overwrite = await confirm(
        `Config already exists${existing ? ` (vault: ${existing})` : ""}.\nOverwrite?`
      );
      if (!overwrite) die("cancelled");
    }

    try {
      mkdirSync(vaultDir, { recursive: true });
    } catch {
      die(`cannot create directory: ${vaultDir}`);
    }

    try {
      accessSync(vaultDir, fsConstants.W_OK);
    } catch {
      die(`directory is not writable: ${vaultDir}`);
    }

    try {
      mkdirSync(dirname(configPath), { recursive: true });
      writeFileSync(configPath, JSON.stringify({ data_dir: vaultDir }, null, 2) + "\n", "utf8");
    } catch {
      die(`cannot write config file: ${configPath}`);
    }

    process.stdin.destroy();
    process.stdout.write(`Vault configured: ${vaultDir}\nConfig saved to: ${configPath}\n`);
  });

// ── go ────────────────────────────────────────────────────────────────────────

program.parseAsync().catch((err: unknown) => die(err instanceof Error ? err.message : String(err)));
