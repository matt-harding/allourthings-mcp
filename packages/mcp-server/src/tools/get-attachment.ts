import { z } from "zod";
import { extname } from "path";
import type { Backend } from "../backends/interface.js";

export const getAttachmentInputSchema = z.object({
  item_id: z.string().describe("ID of the item"),
  filename: z.string().describe("Filename of the attachment to retrieve"),
}).strict();

export const MAX_EMBED_BYTES = 10 * 1024 * 1024;

const IMAGE_TYPES: Record<string, string> = {
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".png": "image/png",
  ".gif": "image/gif",
  ".webp": "image/webp",
};

const TEXT_TYPES: Record<string, string> = {
  ".txt": "text/plain",
  ".md": "text/markdown",
  ".csv": "text/csv",
  ".json": "application/json",
};

function formatSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
}

export async function getAttachment(
  backend: Backend,
  input: z.infer<typeof getAttachmentInputSchema>,
  maxEmbedBytes = MAX_EMBED_BYTES
) {
  const data = await backend.getAttachment(input.item_id, input.filename);
  const item = await backend.getItem(input.item_id).catch(() => null);
  const record = item?.attachments?.find((a) => a.filename === input.filename);

  const details = [
    record ? `kind: ${record.type}` : null,
    record?.label ? `label: ${record.label}` : null,
    `size: ${formatSize(data.byteLength)}`,
  ].filter(Boolean);
  const summary = { type: "text" as const, text: `${input.filename} (${details.join(", ")})` };

  if (data.byteLength > maxEmbedBytes) {
    summary.text +=
      `\nThis file is too large to send to the assistant (limit ${formatSize(maxEmbedBytes)}). ` +
      `It is stored in the user's vault with the item${item ? ` ${item.name}` : ""}.`;
    return { content: [summary] };
  }

  const ext = extname(input.filename).toLowerCase();
  const uri = `allourthings://items/${encodeURIComponent(input.item_id)}/attachments/${encodeURIComponent(input.filename)}`;
  if (IMAGE_TYPES[ext]) {
    return {
      content: [summary, { type: "image" as const, data: data.toString("base64"), mimeType: IMAGE_TYPES[ext] }],
    };
  }
  if (TEXT_TYPES[ext]) {
    return {
      content: [summary, { type: "resource" as const, resource: { uri, mimeType: TEXT_TYPES[ext], text: data.toString("utf8") } }],
    };
  }
  const mimeType = ext === ".pdf" ? "application/pdf" : "application/octet-stream";
  return {
    content: [summary, { type: "resource" as const, resource: { uri, mimeType, blob: data.toString("base64") } }],
  };
}
