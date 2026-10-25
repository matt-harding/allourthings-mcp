import { z } from "zod";
import type { Backend } from "../backends/interface.js";
import { errorResult, textResult } from "./result.js";

export const updateItemInputSchema = z.object({
  id: z.string().describe("Item ID to update (8-character hex, from the id field on the item)"),
  updates: z.record(z.unknown()).describe(
    "Fields to update. Any item field can be updated: name, category, brand, model, purchase_date, purchase_price, currency, warranty_expires, retailer, location, features, notes, tags, serial_number. Custom fields are also accepted. Set a field to null to clear it."
  ),
}).strict();

export async function updateItem(
  backend: Backend,
  input: z.infer<typeof updateItemInputSchema>
) {
  const item = await backend.updateItem(input.id, input.updates);
  return item
    ? textResult(JSON.stringify(item, null, 2))
    : errorResult(`No item found with id: ${input.id}`);
}
