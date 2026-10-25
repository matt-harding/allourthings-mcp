import { z } from "zod";
import { basename } from "path";
import type { Backend } from "../backends/interface.js";
import { errorResult, textResult } from "./result.js";

const TIMEOUT_MS = 30_000;
const MAX_BYTES = 50 * 1024 * 1024; // 50 MB

export const attachFromUrlInputSchema = z.object({
  item_id: z.string().describe("ID of the item to attach the file to"),
  url: z.string().url().describe("URL of the file to download and attach"),
  kind: z
    .enum(["manual", "receipt", "photo", "warranty", "other"])
    .describe("Type of attachment"),
  filename: z
    .string()
    .optional()
    .describe("Filename to store the attachment as — if omitted, taken from the server's Content-Disposition header or the final URL"),
  label: z.string().optional().describe("Human-readable label (e.g. 'User Manual')"),
}).strict();

function isPlainFilename(name: string): boolean {
  return name.length > 0 && name !== "." && name !== ".." && !/[\\/]/.test(name);
}

function safeDecode(s: string): string {
  try {
    return decodeURIComponent(s);
  } catch {
    return s;
  }
}

export function filenameFromContentDisposition(header: string | null): string | null {
  if (!header) return null;
  const extended = /filename\*\s*=\s*([^']*)'[^']*'([^;]+)/i.exec(header);
  if (extended) return safeDecode(extended[2].trim().replace(/^"|"$/g, ""));
  const plain = /filename\s*=\s*("([^"]*)"|[^;]+)/i.exec(header);
  if (plain) return (plain[2] ?? plain[1]).trim();
  return null;
}

export function inferFilename(contentDisposition: string | null, finalUrl: string): string {
  const fromHeader = filenameFromContentDisposition(contentDisposition);
  if (fromHeader) {
    const name = basename(fromHeader.replace(/\\/g, "/"));
    if (isPlainFilename(name)) return name;
  }
  const fromUrl = basename(safeDecode(new URL(finalUrl).pathname));
  return isPlainFilename(fromUrl) ? fromUrl : "attachment";
}

export async function attachFromUrl(
  backend: Backend,
  input: z.infer<typeof attachFromUrlInputSchema>
) {
  // Check cheap preconditions before spending a download on them.
  if (input.filename !== undefined && !isPlainFilename(input.filename)) {
    return errorResult(`Invalid filename: ${input.filename}. Use a plain name without slashes.`);
  }
  const existing = await backend.getItem(input.item_id).catch(() => null);
  if (!existing || existing.id !== input.item_id) {
    return errorResult(`No item found with id: ${input.item_id}`);
  }

  const abort = new AbortController();
  const timer = setTimeout(() => abort.abort(), TIMEOUT_MS);

  let response: Response;
  try {
    response = await fetch(input.url, { signal: abort.signal });
  } catch (err: unknown) {
    clearTimeout(timer);
    const isTimeout = err instanceof Error && err.name === "AbortError";
    return errorResult(
      isTimeout
        ? `Download timed out after ${TIMEOUT_MS / 1000}s. The server may be blocking automated requests or the file is too slow to respond. Try a different direct download URL.`
        : `Network error fetching URL: ${err instanceof Error ? err.message : String(err)}. Check the URL is correct and publicly accessible.`
    );
  }

  clearTimeout(timer);

  if (!response.ok) {
    const hint =
      response.status === 403 || response.status === 401
        ? " The server is blocking automated downloads. Try finding a direct PDF link from a different source."
        : response.status === 404
        ? " The file was not found at this URL. It may have moved — try searching for an updated link."
        : "";
    return errorResult(`Download failed: HTTP ${response.status} ${response.statusText}.${hint}`);
  }

  const contentType = response.headers.get("content-type") ?? "";
  const contentLength = Number(response.headers.get("content-length") ?? 0);

  if (contentLength > MAX_BYTES) {
    return errorResult(
      `File is too large to attach (${Math.round(contentLength / 1024 / 1024)} MB — limit is ${MAX_BYTES / 1024 / 1024} MB). Try finding a compressed or alternative version.`
    );
  }

  if (contentType.startsWith("text/html")) {
    return errorResult(
      "The URL returned an HTML page rather than a file. This is likely a product page or login wall, not a direct download link. Try right-clicking the download button on the page and copying the direct PDF link."
    );
  }

  const buffer = Buffer.from(await response.arrayBuffer());

  if (buffer.byteLength > MAX_BYTES) {
    return errorResult(
      `File is too large to attach (${Math.round(buffer.byteLength / 1024 / 1024)} MB — limit is ${MAX_BYTES / 1024 / 1024} MB).`
    );
  }

  const filename =
    input.filename ??
    inferFilename(response.headers.get("content-disposition"), response.url || input.url);

  const item = await backend.addAttachment(input.item_id, filename, input.kind, buffer, input.label);

  return textResult(JSON.stringify(item, null, 2));
}
