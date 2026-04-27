import { describe, test, expect, beforeEach, afterEach } from "bun:test";
import { mkdtemp, rm } from "fs/promises";
import { tmpdir } from "os";
import { join } from "path";
import { NativeBackend } from "../backends/native.js";
import { resolveCacheDir } from "../config.js";

describe("NativeBackend", () => {
  let dataDir: string;
  let backend: NativeBackend;

  beforeEach(async () => {
    dataDir = await mkdtemp(join(tmpdir(), "aot-test-"));
    backend = new NativeBackend(dataDir);
  });

  afterEach(async () => {
    await rm(dataDir, { recursive: true, force: true });
    await rm(resolveCacheDir(dataDir), { recursive: true, force: true }).catch(() => {});
  });

  // ── CRUD ───────────────────────────────────────────────────────────────────

  test("addItem returns item with generated id and timestamps", async () => {
    const item = await backend.addItem({ name: "Bosch Washing Machine" });

    expect(item.id).toMatch(/^[0-9a-f]{8}$/);
    expect(item.name).toBe("Bosch Washing Machine");
    expect(item.created_at).toBeTruthy();
    expect(item.updated_at).toBeTruthy();
  });

  test("getItem finds item by id", async () => {
    const added = await backend.addItem({ name: "Kettle" });
    const found = await backend.getItem(added.id);

    expect(found?.id).toBe(added.id);
    expect(found?.name).toBe("Kettle");
  });

  test("getItem finds item by name", async () => {
    await backend.addItem({ name: "Espresso Machine" });
    const found = await backend.getItem("Espresso Machine");

    expect(found?.name).toBe("Espresso Machine");
  });

  test("getItem returns null for unknown id", async () => {
    expect(await backend.getItem("00000000")).toBeNull();
  });

  test("updateItem merges changes and updates updated_at", async () => {
    const item = await backend.addItem({ name: "Laptop", category: "Electronics" });
    const updated = await backend.updateItem(item.id, { brand: "Apple" });

    expect(updated?.name).toBe("Laptop");
    expect(updated?.brand).toBe("Apple");
    expect(updated?.category).toBe("Electronics");
    expect(updated?.updated_at).not.toBe(item.updated_at);
  });

  test("updateItem returns null for unknown id", async () => {
    expect(await backend.updateItem("00000000", { name: "Ghost" })).toBeNull();
  });

  test("deleteItem removes the item", async () => {
    const item = await backend.addItem({ name: "Old Toaster" });
    expect(await backend.deleteItem(item.id)).toBe(true);
    expect(await backend.getItem(item.id)).toBeNull();
  });

  test("deleteItem returns false for unknown id", async () => {
    expect(await backend.deleteItem("00000000")).toBe(false);
  });

  // ── listItems ──────────────────────────────────────────────────────────────

  test("listItems returns all items when no filter", async () => {
    await backend.addItem({ name: "Item A" });
    await backend.addItem({ name: "Item B" });
    await backend.addItem({ name: "Item C" });

    const items = await backend.listItems();
    expect(items).toHaveLength(3);
  });

  test("listItems returns empty array when catalog is empty", async () => {
    expect(await backend.listItems()).toHaveLength(0);
  });

  test("listItems filters by category", async () => {
    await backend.addItem({ name: "MacBook", category: "Electronics" });
    await backend.addItem({ name: "Hammer", category: "Tools" });
    await backend.addItem({ name: "iPhone", category: "Electronics" });

    const results = await backend.listItems({ category: "Electronics" });
    expect(results).toHaveLength(2);
    expect(results.every((i) => i.category === "Electronics")).toBe(true);
  });

  test("listItems category filter is case-sensitive", async () => {
    await backend.addItem({ name: "MacBook", category: "Electronics" });

    expect(await backend.listItems({ category: "electronics" })).toHaveLength(0);
    expect(await backend.listItems({ category: "Electronics" })).toHaveLength(1);
  });

  test("listItems filters by subcategory", async () => {
    await backend.addItem({ name: "MacBook", category: "Electronics", subcategory: "Laptop" });
    await backend.addItem({ name: "iPhone", category: "Electronics", subcategory: "Phone" });
    await backend.addItem({ name: "Blender", category: "Appliances", subcategory: "Kitchen" });

    const results = await backend.listItems({ subcategory: "Laptop" });
    expect(results).toHaveLength(1);
    expect(results[0].name).toBe("MacBook");
  });

  test("listItems filters by tags with AND logic", async () => {
    await backend.addItem({ name: "Item A", tags: ["red", "fragile"] });
    await backend.addItem({ name: "Item B", tags: ["red"] });
    await backend.addItem({ name: "Item C", tags: ["fragile"] });

    const results = await backend.listItems({ tags: ["red", "fragile"] });
    expect(results).toHaveLength(1);
    expect(results[0].name).toBe("Item A");
  });

  test("listItems combines category and subcategory filters", async () => {
    await backend.addItem({ name: "Drill", category: "Tools", subcategory: "Power" });
    await backend.addItem({ name: "Hammer", category: "Tools", subcategory: "Hand" });
    await backend.addItem({ name: "Blender", category: "Appliances", subcategory: "Power" });

    const results = await backend.listItems({ category: "Tools", subcategory: "Power" });
    expect(results).toHaveLength(1);
    expect(results[0].name).toBe("Drill");
  });

  // ── searchItems ────────────────────────────────────────────────────────────

  test("searchItems returns items matching query", async () => {
    await backend.addItem({ name: "Bosch Drill", brand: "Bosch" });
    await backend.addItem({ name: "Makita Saw" });

    const results = await backend.searchItems("bosch");
    expect(results).toHaveLength(1);
    expect(results[0].name).toBe("Bosch Drill");
  });

  test("searchItems returns empty array when nothing matches", async () => {
    await backend.addItem({ name: "Kettle" });
    expect(await backend.searchItems("xyz-no-match")).toHaveLength(0);
  });

  // ── cache write-through ────────────────────────────────────────────────────

  test("item added is immediately visible in listItems", async () => {
    const item = await backend.addItem({ name: "Toaster", category: "Appliances" });
    const results = await backend.listItems({ category: "Appliances" });

    expect(results).toHaveLength(1);
    expect(results[0].id).toBe(item.id);
  });

  test("item updated is immediately reflected in listItems", async () => {
    const item = await backend.addItem({ name: "TV", category: "Electronics" });
    await backend.updateItem(item.id, { category: "Appliances" });

    expect(await backend.listItems({ category: "Electronics" })).toHaveLength(0);
    expect(await backend.listItems({ category: "Appliances" })).toHaveLength(1);
  });

  test("item deleted is immediately absent from listItems", async () => {
    const item = await backend.addItem({ name: "Broken Lamp" });
    await backend.deleteItem(item.id);

    expect(await backend.listItems()).toHaveLength(0);
  });

  // ── custom fields ──────────────────────────────────────────────────────────

  test("custom fields survive add and list round-trip", async () => {
    await backend.addItem({
      name: "Server Rack",
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      ...(({ serial_number: "SRV-001", rack_units: 2 }) as any),
    });

    const results = await backend.listItems();
    expect(results[0].serial_number).toBe("SRV-001");
    expect(results[0].rack_units).toBe(2);
  });

  // ── getItemFields ──────────────────────────────────────────────────────────

  test("getItemFields returns all field names in use", async () => {
    await backend.addItem({ name: "Laptop", category: "Electronics", subcategory: "Laptop" });
    await backend.addItem({
      name: "Savings Account",
      category: "Financial",
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      ...(({ account_number: "12345678" }) as any),
    });

    const fields = await backend.getItemFields();
    expect(fields).toContain("name");
    expect(fields).toContain("category");
    expect(fields).toContain("subcategory");
    expect(fields).toContain("account_number");
  });

  test("getItemFields returns empty when catalog is empty", async () => {
    const fields = await backend.getItemFields();
    expect(fields).toHaveLength(0);
  });
});
