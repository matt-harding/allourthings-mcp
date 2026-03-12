import { z } from "zod";
import type { Backend } from "../backends/interface.js";

export const searchItemsInputSchema = z.object({
  query: z.string().describe("Search query — matches across all item fields"),
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
  const summary = items.map((item) => `- ${item.name} (${item.id})`).join("\n");
  return {
    content: [{ type: "text" as const, text: `${items.length} result(s):\n${summary}` }],
  };
}
