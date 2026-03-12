import { z } from "zod";
import type { Backend } from "../backends/interface.js";

export const updateItemInputSchema = z.object({
  id: z.string().describe("Item ID to update"),
  updates: z.record(z.unknown()).describe("Fields to update"),
});

export async function updateItem(
  backend: Backend,
  input: z.infer<typeof updateItemInputSchema>
) {
  const item = await backend.updateItem(input.id, input.updates as any);
  if (!item) {
    return {
      content: [{ type: "text" as const, text: `No item found with id: ${input.id}` }],
    };
  }
  return {
    content: [{ type: "text" as const, text: `Updated: ${item.name}` }],
  };
}
