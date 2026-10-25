import { z } from "zod";
import type { Backend } from "../backends/interface.js";
import { errorResult, textResult } from "./result.js";

export const deleteAttachmentInputSchema = z.object({
  item_id: z.string().describe("ID of the item"),
  filename: z.string().describe("Filename of the attachment to delete"),
}).strict();

export async function deleteAttachment(
  backend: Backend,
  input: z.infer<typeof deleteAttachmentInputSchema>
) {
  const item = await backend.deleteAttachment(input.item_id, input.filename);
  return item
    ? textResult(JSON.stringify(item, null, 2))
    : errorResult(`No item found with id: ${input.item_id}`);
}
