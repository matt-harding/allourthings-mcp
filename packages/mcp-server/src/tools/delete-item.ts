import { z } from "zod";
import type { Backend } from "../backends/interface.js";
import { errorResult, textResult } from "./result.js";

export const deleteItemInputSchema = z.object({
  id: z.string().describe("Item ID to delete"),
}).strict();

export async function deleteItem(
  backend: Backend,
  input: z.infer<typeof deleteItemInputSchema>
) {
  const deleted = await backend.deleteItem(input.id);
  return deleted
    ? textResult(`Deleted item ${input.id}`)
    : errorResult(`No item found with id: ${input.id}`);
}
