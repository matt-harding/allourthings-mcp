import { z } from "zod";
import type { Backend } from "../backends/interface.js";

export const getItemInputSchema = z.object({
  id_or_name: z.string().describe("Item ID or name. Tries exact ID match first, then exact name match, then substring match."),
});

export async function getItem(
  backend: Backend,
  input: z.infer<typeof getItemInputSchema>
) {
  const item = await backend.getItem(input.id_or_name);
  if (!item) {
    return {
      content: [{ type: "text" as const, text: `No item found for: ${input.id_or_name}` }],
    };
  }
  return {
    content: [{ type: "text" as const, text: JSON.stringify(item, null, 2) }],
  };
}
