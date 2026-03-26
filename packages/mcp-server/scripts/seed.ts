/**
 * Seed script — populates the vault with realistic test items.
 *
 * Usage:
 *   bun packages/mcp-server/scripts/seed.ts           # append items
 *   bun packages/mcp-server/scripts/seed.ts --reset   # clear first, then seed
 *
 * Respects --data-dir arg or ALLOURTHINGS_DATA_DIR env var (default: ./dev-vault)
 */

import { writeFile, mkdir, readdir, rm } from "fs/promises";
import { existsSync } from "fs";
import { join } from "path";
import { randomBytes } from "crypto";

const argIndex = process.argv.indexOf("--data-dir");
const dataDir =
  argIndex !== -1 && process.argv[argIndex + 1]
    ? process.argv[argIndex + 1]
    : process.env.ALLOURTHINGS_DATA_DIR ?? "./dev-vault";

const reset = process.argv.includes("--reset");
const itemsDir = join(dataDir, "items");

function generateId(): string {
  return randomBytes(4).toString("hex");
}

function toSlug(name: string): string {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 50)
    .replace(/-+$/, "");
}

const now = new Date();
const daysAgo = (n: number) =>
  new Date(now.getTime() - n * 86_400_000).toISOString().split("T")[0];
const daysAhead = (n: number) =>
  new Date(now.getTime() + n * 86_400_000).toISOString().split("T")[0];

const seedItems = [
  {
    name: "Bosch Serie 6 Washing Machine",
    category: "appliance",
    brand: "Bosch",
    model: "WGG244A9GB",
    purchase_date: daysAgo(400),
    purchase_price: 649,
    currency: "GBP",
    retailer: "John Lewis",
    warranty_expires: daysAhead(330),
    location: "kitchen",
    tags: ["white goods", "laundry"],
    notes: "1400 rpm spin. Uses programme 3 for cottons.",
  },
  {
    name: "Samsung 65\" QLED TV",
    category: "electronics",
    brand: "Samsung",
    model: "QE65Q80CATXXU",
    purchase_date: daysAgo(180),
    purchase_price: 1099,
    currency: "GBP",
    retailer: "Currys",
    warranty_expires: daysAhead(550),
    location: "living room",
    tags: ["tv", "4k"],
  },
  {
    name: "Apple MacBook Pro 14\"",
    category: "electronics",
    brand: "Apple",
    model: "MacBook Pro 14-inch M3 Pro",
    purchase_date: daysAgo(60),
    purchase_price: 1999,
    currency: "GBP",
    retailer: "Apple Store",
    warranty_expires: daysAhead(305),
    location: "office",
    tags: ["laptop", "work"],
    serial_number: "C02XG0Y1JGH7",
  },
  {
    name: "Dyson V15 Detect",
    category: "appliance",
    brand: "Dyson",
    model: "V15 Detect Absolute",
    purchase_date: daysAgo(290),
    purchase_price: 599,
    currency: "GBP",
    retailer: "Dyson",
    warranty_expires: daysAhead(440),
    location: "utility room",
    tags: ["hoover", "cordless"],
    notes: "Filter washed monthly. Bin emptied weekly.",
  },
  {
    name: "IKEA KALLAX Bookshelf",
    category: "furniture",
    brand: "IKEA",
    model: "KALLAX 4x2",
    purchase_date: daysAgo(900),
    purchase_price: 119,
    currency: "GBP",
    retailer: "IKEA",
    location: "living room",
    tags: ["storage", "shelving"],
  },
  {
    name: "Nespresso Vertuo Next",
    category: "appliance",
    brand: "Nespresso",
    model: "Vertuo Next XN910",
    purchase_date: daysAgo(500),
    purchase_price: 79,
    currency: "GBP",
    retailer: "Amazon",
    warranty_expires: daysAgo(135),
    location: "kitchen",
    tags: ["coffee", "kitchen"],
    notes: "Descale every 3 months. Warranty expired.",
  },
  {
    name: "Nintendo Switch OLED",
    category: "electronics",
    brand: "Nintendo",
    model: "Switch OLED (White)",
    purchase_date: daysAgo(700),
    purchase_price: 309,
    currency: "GBP",
    retailer: "GAME",
    warranty_expires: daysAgo(335),
    location: "living room",
    tags: ["gaming", "console"],
  },
  {
    name: "Karcher K5 Pressure Washer",
    category: "appliance",
    brand: "Karcher",
    model: "K5 Premium Full Control",
    purchase_date: daysAgo(200),
    purchase_price: 249,
    currency: "GBP",
    retailer: "B&Q",
    warranty_expires: daysAhead(165),
    location: "garage",
    tags: ["outdoor", "cleaning"],
  },
  {
    name: "Nest Learning Thermostat",
    category: "smart home",
    brand: "Google",
    model: "Nest Learning Thermostat 3rd Gen",
    purchase_date: daysAgo(800),
    purchase_price: 219,
    currency: "GBP",
    retailer: "Google Store",
    warranty_expires: daysAgo(165),
    location: "hallway",
    tags: ["smart home", "heating"],
    notes: "Linked to Google Home. Schedule set for weekdays 7am–10pm.",
  },
  {
    name: "Spotify Premium",
    category: "subscription",
    brand: "Spotify",
    purchase_date: daysAgo(1200),
    purchase_price: 11.99,
    currency: "GBP",
    retailer: "Spotify",
    location: "digital",
    tags: ["music", "streaming", "subscription"],
    notes: "Family plan. Renews monthly.",
  },
  {
    name: "Meaco 12L Dehumidifier",
    category: "appliance",
    brand: "Meaco",
    model: "Meaco12L Low Energy",
    purchase_date: daysAgo(350),
    purchase_price: 189,
    currency: "GBP",
    retailer: "Amazon",
    warranty_expires: daysAhead(380),
    location: "bedroom",
    tags: ["appliance", "air quality"],
  },
  {
    name: "Ronseal Fence Paint — Harvest Gold",
    category: "diy",
    brand: "Ronseal",
    model: "Harvest Gold 9L",
    purchase_date: daysAgo(45),
    purchase_price: 34.99,
    currency: "GBP",
    retailer: "B&Q",
    location: "garage",
    tags: ["paint", "outdoor", "diy"],
    notes: "~2L remaining. Used on rear fence panels.",
  },
];

async function main() {
  if (reset && existsSync(itemsDir)) {
    await rm(itemsDir, { recursive: true });
    console.log("--reset: cleared existing items.");
  }

  await mkdir(itemsDir, { recursive: true });

  let existingCount = 0;
  if (!reset && existsSync(itemsDir)) {
    const entries = await readdir(itemsDir);
    existingCount = entries.length;
    if (existingCount > 0) {
      console.log(`Found ${existingCount} existing item(s) — appending.`);
    }
  }

  const timestamp = now.toISOString();
  const newItems = seedItems.map((item) => ({
    ...item,
    id: generateId(),
    created_at: timestamp,
    updated_at: timestamp,
  }));

  for (const item of newItems) {
    const dir = join(itemsDir, `${toSlug(item.name)}-${item.id}`);
    await mkdir(dir, { recursive: true });
    await writeFile(join(dir, "item.json"), JSON.stringify(item, null, 2));
  }

  console.log(`\nSeeded ${newItems.length} items:`);
  for (const item of newItems) {
    const slug = toSlug(item.name);
    console.log(`  + ${slug}-${item.id}/`);
  }
  console.log(`\nVault: ${dataDir} (${existingCount + newItems.length} total items)`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
