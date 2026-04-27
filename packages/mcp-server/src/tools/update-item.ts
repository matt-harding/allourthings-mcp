import { z } from "zod";
import type { Backend } from "../backends/interface.js";

export const updateItemInputSchema = z.object({
  id: z.string().describe("Item ID to update (8-character hex, from the id field on the item)"),
  updates: z.record(z.unknown()).describe(
    "Fields to update. Any item field can be updated: name, category, brand, model, purchase_date, purchase_price, currency, warranty_expires, retailer, location, features, notes, tags, serial_number. Custom fields are also accepted."
  ),
});

export async function updateItem(
  backend: Backend,
  input: z.infer<typeof updateItemInputSchema>
) {
  const item = await backend.updateItem(input.id, input.updates);
  if (!item) {
    return {
      content: [{ type: "text" as const, text: `No item found with id: ${input.id}` }],
    };
  }
  return {
    content: [{ type: "text" as const, text: JSON.stringify(item, null, 2) }],
  };
}
