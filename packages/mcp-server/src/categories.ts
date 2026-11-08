// Shared by the MCP server and the CLI (bundled into each).

export interface CategorySummary {
  categories: Array<{ name: string; count: number; subcategories: Array<{ name: string; count: number }> }>;
  tags: Array<{ name: string; count: number }>;
}

export const NO_CATEGORY = "(none)";

type Categorised = { category?: string; subcategory?: string; tags?: string[] };

function sortedCounts(counts: Map<string, number>, last?: string) {
  return [...counts]
    .map(([name, count]) => ({ name, count }))
    .sort((a, b) => Number(a.name === last) - Number(b.name === last) || a.name.localeCompare(b.name));
}

function bump(counts: Map<string, number>, key: string) {
  counts.set(key, (counts.get(key) ?? 0) + 1);
}

export function summariseCategories(items: Categorised[]): CategorySummary {
  const categories = new Map<string, number>();
  const subcategories = new Map<string, Map<string, number>>();
  const tags = new Map<string, number>();
  for (const item of items) {
    const category = item.category || NO_CATEGORY;
    bump(categories, category);
    if (item.subcategory) {
      if (!subcategories.has(category)) subcategories.set(category, new Map());
      bump(subcategories.get(category)!, item.subcategory);
    }
    for (const tag of new Set(item.tags ?? [])) bump(tags, tag);
  }
  return {
    categories: sortedCounts(categories, NO_CATEGORY).map((c) => ({
      ...c,
      subcategories: sortedCounts(subcategories.get(c.name) ?? new Map()),
    })),
    tags: sortedCounts(tags),
  };
}

export function formatCategories(summary: CategorySummary): string {
  if (summary.categories.length === 0) return "No items in catalog yet.";
  const lines = ["Categories:"];
  for (const c of summary.categories) {
    lines.push(`- ${c.name} (${c.count})`);
    for (const s of c.subcategories) lines.push(`  - ${s.name} (${s.count})`);
  }
  if (summary.tags.length === 0) {
    lines.push("Tags: none");
  } else {
    lines.push("Tags:", ...summary.tags.map((t) => `- ${t.name} (${t.count})`));
  }
  return lines.join("\n");
}
