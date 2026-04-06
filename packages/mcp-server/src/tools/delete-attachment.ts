import { z } from "zod";
import type { Backend } from "../backends/interface.js";

export const deleteAttachmentInputSchema = z.object({
  item_id: z.string().describe("ID of the item"),
  filename: z.string().describe("Filename of the attachment to delete"),
});

export async function deleteAttachment(
  backend: Backend,
  input: z.infer<typeof deleteAttachmentInputSchema>
) {
  const item = await backend.deleteAttachment(input.item_id, input.filename);
  return {
    content: [
      {
        type: "text" as const,
        text: item ? JSON.stringify(item, null, 2) : "Attachment deleted (item not found)",
      },
    ],
  };
}
