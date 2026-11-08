import { z } from "zod";
import type { Backend } from "../backends/interface.js";
import { errorResult, textResult } from "./result.js";
import { existingAttachmentError } from "./add-attachment.js";
import { download, DownloadError, isPlainFilename, type DownloadOptions } from "../download.js";

export const attachFromUrlInputSchema = z.object({
  item_id: z.string().describe("ID of the item to attach the file to"),
  url: z.string().url().describe("Public http(s) URL of the file to download and attach"),
  kind: z
    .enum(["manual", "receipt", "photo", "warranty", "other"])
    .describe("Type of attachment"),
  filename: z
    .string()
    .optional()
    .describe("Recommended: a readable name such as 'nutribullet-600-manual.pdf'. If omitted, the name comes from the server's Content-Disposition header or the URL and may be meaningless"),
  label: z.string().optional().describe("Human-readable label (e.g. 'User Manual')"),
}).strict();

export async function attachFromUrl(
  backend: Backend,
  input: z.infer<typeof attachFromUrlInputSchema>,
  downloadOptions?: DownloadOptions
) {
  // Check cheap preconditions before spending a download on them.
  if (input.filename !== undefined && !isPlainFilename(input.filename)) {
    return errorResult(`Invalid filename: ${input.filename}. Use a plain name without slashes.`);
  }
  const existing = await backend.getItem(input.item_id).catch(() => null);
  if (!existing || existing.id !== input.item_id) {
    return errorResult(`No item found with id: ${input.item_id}`);
  }
  if (input.filename !== undefined) {
    const clash = await existingAttachmentError(backend, input.item_id, input.filename);
    if (clash) return clash;
  }

  let downloaded;
  try {
    downloaded = await download(input.url, downloadOptions);
  } catch (err) {
    if (err instanceof DownloadError) return errorResult(err.message);
    throw err;
  }
  const filename = input.filename ?? downloaded.filename;

  // Inferred names are only known after the download; recheck in case it changed meanwhile.
  const clash = await existingAttachmentError(backend, input.item_id, filename);
  if (clash) return clash;

  const item = await backend.addAttachment(input.item_id, filename, input.kind, downloaded.data, input.label);

  return textResult(JSON.stringify(item, null, 2));
}
