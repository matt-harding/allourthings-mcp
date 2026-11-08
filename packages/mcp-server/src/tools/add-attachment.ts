import { z } from "zod";
import type { Backend } from "../backends/interface.js";
import type { Item } from "../schema.js";
import { errorResult } from "./result.js";

export const addAttachmentInputSchema = z.object({
  item_id: z.string().describe("ID of the item to attach the file to"),
  filename: z.string().describe("Filename to store the attachment as (e.g. manual.pdf)"),
  kind: z
    .enum(["manual", "receipt", "photo", "warranty", "other"])
    .describe("Type of attachment"),
  data_base64: z
    .string()
    .refine((s) => {
      const compact = s.replace(/\s+/g, "");
      return compact.length % 4 === 0 && /^[A-Za-z0-9+/]*={0,2}$/.test(compact);
    }, "must be valid base64")
    .describe("Base64-encoded file contents"),
  label: z.string().optional().describe("Human-readable label (e.g. 'Washing machine manual')"),
}).strict();

/** Error result if the item already has this filename (case-insensitive, as macOS and Windows are). */
export async function existingAttachmentError(backend: Backend, itemId: string, filename: string) {
  const item: Item | null = await backend.getItem(itemId).catch(() => null);
  if (!item || item.id !== itemId) return null;
  const lower = filename.toLowerCase();
  const clash = item.attachments?.find((a) => a.filename.toLowerCase() === lower);
  return clash
    ? errorResult(`${item.name} already has an attachment named "${clash.filename}". Delete it first or choose another filename.`)
    : null;
}

export async function addAttachment(
  backend: Backend,
  input: z.infer<typeof addAttachmentInputSchema>
) {
  const clash = await existingAttachmentError(backend, input.item_id, input.filename);
  if (clash) return clash;
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
