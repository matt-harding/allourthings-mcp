import { z } from "zod";
import type { Backend } from "../backends/interface.js";
import { textResult } from "./result.js";

export const searchItemsInputSchema = z.object({
  query: z.string().max(200).describe("Words to search for. Items containing any of the words are returned, best match first"),
  limit: z.number().int().min(1).max(100).default(20).describe("Maximum number of results (1–100)"),
}).strict();

export async function searchItems(
  backend: Backend,
  input: z.infer<typeof searchItemsInputSchema>
) {
  // One extra result tells us whether there are more than the limit.
  const hits = await backend.search(input.query, input.limit + 1);
  if (hits.length === 0) return textResult(`No items matched: ${input.query}`);

  const shown = hits.slice(0, input.limit);
  const lines = shown.map(({ item, matchedAll }) => {
    const meta = [item.category, item.location].filter(Boolean).join(", ");
    return `- ${item.name}${meta ? ` [${meta}]` : ""} (${item.id})${matchedAll ? " — all words" : ""}`;
  });
  const more = hits.length > input.limit ? `\nShowing the top ${input.limit}; pass a higher limit to see more.` : "";
  return textResult(`${shown.length} result(s), best match first:\n${lines.join("\n")}${more}`);
}
