/**
 * Storage conformance tests.
 *
 * These tests read from test-fixtures/catalog — a static catalog committed to the
 * repository that every client implementation must be able to read correctly.
 * See STORAGE_SPEC.md §9 and test-fixtures/MANIFEST.json for the full assertions.
 *
 * If these tests fail, either the implementation has regressed or the spec has changed
 * and the fixtures need updating. Do not change the fixtures without updating STORAGE_SPEC.md.
 */

import { describe, test, expect } from "bun:test";
import { join } from "path";
import { FilesystemBackend } from "../backends/filesystem.js";
import { toSlug } from "../utils.js";
import manifest from "../../../../test-fixtures/MANIFEST.json";

const FIXTURE_CATALOG = join(import.meta.dir, "../../../../test-fixtures/catalog");

const backend = new FilesystemBackend(FIXTURE_CATALOG);

// ── Fixture reads ─────────────────────────────────────────────────────────────

describe("conformance: fixture reads", () => {
  test(`lists exactly ${manifest.readable_items} readable items (skips ${manifest.skipped_items} malformed)`, async () => {
    const items = await backend.listItems();
    expect(items.length).toBe(manifest.readable_items);
  });

  test("reads minimal item correctly", async () => {
    const item = await backend.getItem("00000001");
    expect(item?.id).toBe("00000001");
    expect(item?.name).toBe("Minimal Item");
    expect(item?.created_at).toBeDefined();
    expect(item?.updated_at).toBeDefined();
  });

  test("reads full item with all well-known fields", async () => {
    const item = await backend.getItem("00000002");
    expect(item?.name).toBe("Full Item");
    expect(item?.category).toBe("electronics");
    expect(item?.purchase_price).toBe(649);
    expect(item?.purchase_date).toBe("2025-02-10");
    expect(item?.warranty_expires).toBe("2027-02-10");
    expect(item?.attachments?.length).toBe(2);
    expect(item?.attachments?.[0]).toEqual({ filename: "manual.pdf", type: "manual", label: "User Guide" });
  });

  test("preserves passthrough custom fields", async () => {
    const item = await backend.getItem("00000003") as any;
    expect(item?.serial_number).toBe("ABC123XYZ");
    expect(item?.rack_unit).toBe(2);
    expect(item?.custom_bool).toBe(true);
  });

  test("silently skips malformed item (00000004) during listing", async () => {
    // The malformed item must not appear in list results.
    // listItems() uses loadAll() which has per-item try/catch.
    const items = await backend.listItems();
    expect(items.some(i => i.id === "00000004")).toBe(false);
  });
});

// ── Slug algorithm ────────────────────────────────────────────────────────────

describe("conformance: slug algorithm", () => {
  for (const { input, output } of manifest.slug_vectors) {
    test(`toSlug("${input}") === "${output}"`, () => {
      expect(toSlug(input)).toBe(output);
    });
  }
});
