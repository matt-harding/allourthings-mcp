import { z } from "zod";
import type { Backend } from "../backends/interface.js";

export const deleteItemInputSchema = z.object({
  id: z.string().regex(/^[0-9a-f]{8}$/).describe("Item ID to delete"),
});

export async function deleteItem(
  backend: Backend,
  input: z.infer<typeof deleteItemInputSchema>
) {
  const deleted = await backend.deleteItem(input.id);
  return {
    content: [
      {
        type: "text" as const,
        text: deleted ? `Deleted item ${input.id}` : `No item found with id: ${input.id}`,
      },
    ],
  };
}
