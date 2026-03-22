import { z } from "zod";
import type { Backend } from "../backends/interface.js";

export const searchItemsInputSchema = z.object({
  query: z.string().max(200).describe("Search query — matches across all item fields"),
});

export async function searchItems(
  backend: Backend,
  input: z.infer<typeof searchItemsInputSchema>
) {
  const items = await backend.searchItems(input.query);
  if (items.length === 0) {
    return {
      content: [{ type: "text" as const, text: `No items matched: ${input.query}` }],
    };
  }
  const summary = items
    .map((item) => {
      const meta = [item.category, item.location].filter(Boolean).join(", ");
      return `- ${item.name}${meta ? ` [${meta}]` : ""} (${item.id})`;
    })
    .join("\n");
  return {
    content: [{ type: "text" as const, text: `${items.length} result(s):\n${summary}` }],
  };
}
