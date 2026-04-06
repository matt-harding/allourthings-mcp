import { z } from "zod";
import type { Backend } from "../backends/interface.js";

export const addAttachmentInputSchema = z.object({
  item_id: z.string().describe("ID of the item to attach the file to"),
  filename: z.string().describe("Filename to store the attachment as (e.g. manual.pdf)"),
  kind: z
    .enum(["manual", "receipt", "photo", "warranty", "other"])
    .describe("Type of attachment"),
  data_base64: z.string().describe("Base64-encoded file contents"),
  label: z.string().optional().describe("Human-readable label (e.g. 'Washing machine manual')"),
});

export async function addAttachment(
  backend: Backend,
  input: z.infer<typeof addAttachmentInputSchema>
) {
  const data = Buffer.from(input.data_base64, "base64");
  const item = await backend.addAttachment(input.item_id, input.filename, input.kind, data, input.label);
  return {
    content: [
      {
        type: "text" as const,
        text: JSON.stringify(item, null, 2),
      },
    ],
  };
}
