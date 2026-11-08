import { describe, test, expect } from "bun:test";
import { formatCategories, summariseCategories } from "../categories.js";

describe("list_categories summary (R9)", () => {
  const items = [
    { category: "Appliance", subcategory: "Kitchen Appliance", tags: ["white goods"] },
    { category: "Appliance", subcategory: "Kitchen Appliance", tags: ["white goods", "white goods"] },
    { category: "Appliance", subcategory: "Laundry" },
    { category: "Appliance" },
    { category: "Electronic", subcategory: "Music", tags: ["audio"] },
    { subcategory: "Loose" },
    {},
  ];

  test("counts categories, nested subcategories and tags, sorted by name with (none) last", () => {
    expect(summariseCategories(items)).toEqual({
      categories: [
        {
          name: "Appliance",
          count: 4,
          subcategories: [
            { name: "Kitchen Appliance", count: 2 },
            { name: "Laundry", count: 1 },
          ],
        },
        { name: "Electronic", count: 1, subcategories: [{ name: "Music", count: 1 }] },
        { name: "(none)", count: 2, subcategories: [{ name: "Loose", count: 1 }] },
      ],
      tags: [
        { name: "audio", count: 1 },
        { name: "white goods", count: 2 },
      ],
    });
  });

  test("formats as an indented list", () => {
    expect(formatCategories(summariseCategories(items))).toBe(
      [
        "Categories:",
        "- Appliance (4)",
        "  - Kitchen Appliance (2)",
        "  - Laundry (1)",
        "- Electronic (1)",
        "  - Music (1)",
        "- (none) (2)",
        "  - Loose (1)",
        "Tags:",
        "- audio (1)",
        "- white goods (2)",
      ].join("\n")
    );
  });

  test("says when there are no tags", () => {
    expect(formatCategories(summariseCategories([{ category: "Heating" }]))).toBe(
      "Categories:\n- Heating (1)\nTags: none"
    );
  });

  test("empty vault", () => {
    expect(formatCategories(summariseCategories([]))).toBe("No items in catalog yet.");
  });
});
