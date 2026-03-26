import { describe, test, expect } from "bun:test";
import { toSlug, generateId } from "../utils.js";

describe("toSlug", () => {
  test("lowercases and hyphenates words", () => {
    expect(toSlug("Dyson V15 Detect")).toBe("dyson-v15-detect");
  });

  test("collapses consecutive special chars into one hyphen", () => {
    expect(toSlug("Hello   World!!")).toBe("hello-world");
  });

  test("strips leading and trailing hyphens", () => {
    expect(toSlug("  !!hello!!  ")).toBe("hello");
  });

  test("truncates to 50 chars without a trailing hyphen", () => {
    const long = "a".repeat(30) + " " + "b".repeat(30);
    const slug = toSlug(long);
    expect(slug.length).toBeLessThanOrEqual(50);
    expect(slug).not.toMatch(/-$/);
  });

  test("strips non-ASCII unicode characters", () => {
    // ñ, é etc. are not [a-z0-9] — collapsed into hyphens then trimmed
    expect(toSlug("Ñoño café")).toBe("o-o-caf");
  });

  test("handles numbers-only name", () => {
    expect(toSlug("42")).toBe("42");
  });

  test("handles name with only non-alphanumeric chars", () => {
    expect(toSlug("!!!")).toBe("");
  });

  test("handles mixed alphanumeric and symbols", () => {
    expect(toSlug("Kärcher K5 (2024)")).toBe("k-rcher-k5-2024");
  });
});

describe("generateId", () => {
  test("returns exactly 8 hex characters", () => {
    expect(generateId()).toMatch(/^[0-9a-f]{8}$/);
  });

  test("returns unique values across many calls", () => {
    const ids = new Set(Array.from({ length: 200 }, generateId));
    expect(ids.size).toBe(200);
  });
});
