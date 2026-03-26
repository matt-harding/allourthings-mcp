import { describe, test, expect, beforeEach, afterEach } from "bun:test";
import { existsSync } from "fs";
import { mkdir, writeFile } from "fs/promises";
import { join } from "path";
import { FilesystemBackend } from "../../backends/filesystem.js";
import { createTmpVault, removeTmpVault } from "../helpers/tmp-vault.js";

let vault: string;
let backend: FilesystemBackend;

beforeEach(async () => {
  vault = await createTmpVault();
  backend = new FilesystemBackend(vault);
});

afterEach(async () => {
  await removeTmpVault(vault);
});

// ── addItem ──────────────────────────────────────────────────────────────────

describe("addItem", () => {
  test("creates a {slug}-{id} directory containing item.json", async () => {
    const item = await backend.addItem({ name: "Dyson V15 Detect" });

    expect(item.id).toMatch(/^[0-9a-f]{8}$/);
    expect(item.name).toBe("Dyson V15 Detect");
    expect(item.created_at).toBeDefined();
    expect(item.updated_at).toBeDefined();

    const dir = join(vault, "items", `dyson-v15-detect-${item.id}`);
    expect(existsSync(dir)).toBe(true);
    expect(existsSync(join(dir, "item.json"))).toBe(true);
  });

  test("preserves passthrough custom fields", async () => {
    const item = await backend.addItem({ name: "MacBook", serial_number: "ABC123" } as any);
    const fetched = await backend.getItem(item.id);
    expect((fetched as any).serial_number).toBe("ABC123");
  });

  test("preserves attachments array", async () => {
    const item = await backend.addItem({
      name: "Washing Machine",
      attachments: [{ filename: "manual.pdf", type: "manual" }],
    });
    const fetched = await backend.getItem(item.id);
    expect(fetched?.attachments).toEqual([{ filename: "manual.pdf", type: "manual" }]);
  });
});

// ── getItem ───────────────────────────────────────────────────────────────────

describe("getItem", () => {
  test("finds by exact ID", async () => {
    const added = await backend.addItem({ name: "Samsung TV" });
    const found = await backend.getItem(added.id);
    expect(found?.id).toBe(added.id);
  });

  test("finds by exact name (case-insensitive)", async () => {
    await backend.addItem({ name: "Samsung TV" });
    const found = await backend.getItem("samsung tv");
    expect(found?.name).toBe("Samsung TV");
  });

  test("finds by partial name", async () => {
    await backend.addItem({ name: "Samsung QLED TV" });
    const found = await backend.getItem("QLED");
    expect(found?.name).toBe("Samsung QLED TV");
  });

  test("returns null for unknown ID", async () => {
    expect(await backend.getItem("deadbeef")).toBeNull();
  });
});

// ── listItems ─────────────────────────────────────────────────────────────────

describe("listItems", () => {
  beforeEach(async () => {
    await backend.addItem({ name: "Washing Machine", category: "appliance", location: "kitchen",      tags: ["laundry"] });
    await backend.addItem({ name: "TV",              category: "electronics", location: "living room", tags: ["entertainment"] });
    await backend.addItem({ name: "Hoover",          category: "appliance",   location: "utility",     tags: ["laundry", "cleaning"] });
  });

  test("returns all items with no filter", async () => {
    expect((await backend.listItems()).length).toBe(3);
  });

  test("filters by category", async () => {
    const items = await backend.listItems({ category: "appliance" });
    expect(items.length).toBe(2);
  });

  test("filters by location (case-insensitive)", async () => {
    const items = await backend.listItems({ location: "KITCHEN" });
    expect(items.length).toBe(1);
    expect(items[0].name).toBe("Washing Machine");
  });

  test("filters by tags — all supplied tags must match", async () => {
    const items = await backend.listItems({ tags: ["laundry", "cleaning"] });
    expect(items.length).toBe(1);
    expect(items[0].name).toBe("Hoover");
  });
});

// ── updateItem ────────────────────────────────────────────────────────────────

describe("updateItem", () => {
  test("updates fields on the item", async () => {
    const item = await backend.addItem({ name: "Thermostat" });
    const updated = await backend.updateItem(item.id, { notes: "hallway" });
    expect(updated?.notes).toBe("hallway");
  });

  test("renames the directory when name changes", async () => {
    const item = await backend.addItem({ name: "Old Name" });
    await backend.updateItem(item.id, { name: "New Name" });

    expect(existsSync(join(vault, "items", `old-name-${item.id}`))).toBe(false);
    expect(existsSync(join(vault, "items", `new-name-${item.id}`))).toBe(true);
  });

  test("item is still retrievable by ID after rename", async () => {
    const item = await backend.addItem({ name: "Old Name" });
    await backend.updateItem(item.id, { name: "New Name" });
    const fetched = await backend.getItem(item.id);
    expect(fetched?.name).toBe("New Name");
  });

  test("returns null for unknown ID", async () => {
    expect(await backend.updateItem("deadbeef", { notes: "x" })).toBeNull();
  });
});

// ── deleteItem ────────────────────────────────────────────────────────────────

describe("deleteItem", () => {
  test("removes the item directory entirely", async () => {
    const item = await backend.addItem({ name: "Delete Me" });
    const dir = join(vault, "items", `delete-me-${item.id}`);

    expect(await backend.deleteItem(item.id)).toBe(true);
    expect(existsSync(dir)).toBe(false);
  });

  test("returns false for unknown ID", async () => {
    expect(await backend.deleteItem("deadbeef")).toBe(false);
  });
});

// ── searchItems ───────────────────────────────────────────────────────────────

describe("searchItems", () => {
  test("matches by field value", async () => {
    await backend.addItem({ name: "Dyson Hoover", brand: "Dyson" } as any);
    await backend.addItem({ name: "Samsung TV" });

    const results = await backend.searchItems("dyson");
    expect(results.length).toBe(1);
    expect(results[0].name).toBe("Dyson Hoover");
  });

  test("returns empty array when nothing matches", async () => {
    await backend.addItem({ name: "TV" });
    expect(await backend.searchItems("xxxxxx")).toEqual([]);
  });
});

// ── resilience ────────────────────────────────────────────────────────────────

describe("resilience", () => {
  test("silently skips malformed item.json", async () => {
    await mkdir(join(vault, "items", "bad-item-aaaabbbb"), { recursive: true });
    await writeFile(join(vault, "items", "bad-item-aaaabbbb", "item.json"), "{ not valid json");

    await backend.addItem({ name: "Good Item" });

    const items = await backend.listItems();
    expect(items.length).toBe(1);
    expect(items[0].name).toBe("Good Item");
  });

  test("returns empty list when items/ dir does not exist", async () => {
    expect(await backend.listItems()).toEqual([]);
  });

  test("passthrough fields survive an add → get round-trip", async () => {
    const item = await backend.addItem({ name: "MacBook", serial_number: "ABC123", rack_unit: 2 } as any);
    const fetched = await backend.getItem(item.id);
    expect((fetched as any).serial_number).toBe("ABC123");
    expect((fetched as any).rack_unit).toBe(2);
  });

  test("attachments are preserved through an update", async () => {
    const item = await backend.addItem({
      name: "Washing Machine",
      attachments: [{ filename: "manual.pdf", type: "manual" }],
    });
    await backend.updateItem(item.id, { notes: "updated" });
    const fetched = await backend.getItem(item.id);
    expect(fetched?.attachments).toEqual([{ filename: "manual.pdf", type: "manual" }]);
  });
});
