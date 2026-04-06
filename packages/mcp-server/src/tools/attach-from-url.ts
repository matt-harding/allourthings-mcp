import { z } from "zod";
import { basename } from "path";
import type { Backend } from "../backends/interface.js";

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
    .describe("Filename to store the attachment as — inferred from URL if omitted"),
  label: z.string().optional().describe("Human-readable label (e.g. 'User Manual')"),
});

function errorResult(message: string) {
  return {
    content: [{ type: "text" as const, text: message }],
    isError: true,
  };
}

export async function attachFromUrl(
  backend: Backend,
  input: z.infer<typeof attachFromUrlInputSchema>
) {
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
    (basename(new URL(input.url).pathname) || "attachment");

  const item = await backend.addAttachment(input.item_id, filename, input.kind, buffer, input.label);

  return {
    content: [
      {
        type: "text" as const,
        text: JSON.stringify(item, null, 2),
      },
    ],
  };
}
