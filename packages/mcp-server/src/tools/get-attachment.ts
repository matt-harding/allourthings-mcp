import { z } from "zod";
import type { Backend } from "../backends/interface.js";

export const getAttachmentInputSchema = z.object({
  item_id: z.string().describe("ID of the item"),
  filename: z.string().describe("Filename of the attachment to retrieve"),
});

export async function getAttachment(
  backend: Backend,
  input: z.infer<typeof getAttachmentInputSchema>
) {
  const data = await backend.getAttachment(input.item_id, input.filename);
  return {
    content: [
      {
        type: "text" as const,
        text: data.toString("base64"),
      },
    ],
  };
}
