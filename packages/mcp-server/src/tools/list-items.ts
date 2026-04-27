import { z } from "zod";
import type { Backend } from "../backends/interface.js";

export const listItemsInputSchema = z.object({
  category: z.string().optional().describe("Filter by category"),
  subcategory: z.string().optional().describe("Filter by subcategory"),
  tags: z.array(z.string()).optional().describe("Filter by tags (all must match)"),
});

export async function listItems(
  backend: Backend,
  input: z.infer<typeof listItemsInputSchema>
) {
  const items = await backend.listItems(input);
  if (items.length === 0) {
    return {
      content: [{ type: "text" as const, text: "No items found." }],
    };
  }
  const summary = items
    .map((item) => {
      const meta = [item.category, item.subcategory].filter(Boolean).join(" › ");
      return `- ${item.name}${meta ? ` [${meta}]` : ""} (${item.id})`;
    })
    .join("\n");
  return {
    content: [{ type: "text" as const, text: `${items.length} item(s):\n${summary}` }],
  };
}
