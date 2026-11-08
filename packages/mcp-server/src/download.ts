// Shared by the MCP server and the CLI (bundled into each). Node built-ins only.
import { lookup as dnsLookup } from "dns/promises";
import { isIP } from "net";
import { basename } from "path";

export const TIMEOUT_MS = 30_000;
export const MAX_BYTES = 50 * 1024 * 1024;
const MAX_REDIRECTS = 5;

export class DownloadError extends Error {}

export interface DownloadOptions {
  maxBytes?: number;
  /** Tests only: allow loopback/private addresses. */
  allowPrivate?: boolean;
  /** Tests only. */
  lookup?: (hostname: string) => Promise<string[]>;
  /** Tests only. */
  fetch?: typeof fetch;
}

export interface Download {
  data: Buffer;
  filename: string;
}

// ── Address checks ───────────────────────────────────────────────────────────

const V4_BLOCKED: Array<[string, number]> = [
  ["0.0.0.0", 8], // "this network", incl. unspecified
  ["10.0.0.0", 8],
  ["100.64.0.0", 10], // carrier-grade NAT
  ["127.0.0.0", 8],
  ["169.254.0.0", 16], // link-local, incl. cloud metadata
  ["172.16.0.0", 12],
  ["192.168.0.0", 16],
  ["224.0.0.0", 4], // multicast
  ["240.0.0.0", 4], // reserved, incl. broadcast
];

const V6_BLOCKED: Array<[string, number]> = [
  ["::", 128],
  ["::1", 128],
  ["fc00::", 7], // unique-local
  ["fe80::", 10], // link-local
  ["ff00::", 8], // multicast
];

function v4ToInt(ip: string): number {
  return ip.split(".").reduce((acc, octet) => acc * 256 + Number(octet), 0);
}

function v6ToBigInt(ip: string): bigint {
  let addr = ip.split("%")[0];
  const v4Tail = /(\d+\.\d+\.\d+\.\d+)$/.exec(addr);
  if (v4Tail) {
    const n = v4ToInt(v4Tail[1]);
    addr = addr.slice(0, -v4Tail[1].length) + `${(n >>> 16).toString(16)}:${(n & 0xffff).toString(16)}`;
  }
  const [head, tail] = addr.split("::");
  const headGroups = head ? head.split(":") : [];
  const tailGroups = tail ? tail.split(":") : [];
  const groups = tail === undefined
    ? headGroups
    : [...headGroups, ...Array(8 - headGroups.length - tailGroups.length).fill("0"), ...tailGroups];
  return groups.reduce((acc, g) => (acc << 16n) | BigInt(parseInt(g, 16)), 0n);
}

function inV4(n: number, [base, bits]: [string, number]): boolean {
  const shift = 32 - bits;
  return Math.floor(n / 2 ** shift) === Math.floor(v4ToInt(base) / 2 ** shift);
}

function inV6(n: bigint, [base, bits]: [string, number]): boolean {
  const shift = BigInt(128 - bits);
  return n >> shift === v6ToBigInt(base) >> shift;
}

export function isPrivateAddress(ip: string): boolean {
  const family = isIP(ip.split("%")[0]);
  if (family === 4) {
    const n = v4ToInt(ip);
    return V4_BLOCKED.some((r) => inV4(n, r));
  }
  if (family === 6) {
    const n = v6ToBigInt(ip);
    if (n >> 32n === 0xffffn) return isPrivateAddress(numberToV4(Number(n & 0xffffffffn)));
    return V6_BLOCKED.some((r) => inV6(n, r));
  }
  return true; // not an IP address: refuse rather than guess
}

function numberToV4(n: number): string {
  return [n >>> 24, (n >>> 16) & 255, (n >>> 8) & 255, n & 255].join(".");
}

async function defaultLookup(hostname: string): Promise<string[]> {
  return (await dnsLookup(hostname, { all: true, verbatim: true })).map((a) => a.address);
}

// Known limitation: DNS can change between this check and the fetch (rebinding).
async function assertPublicUrl(url: URL, opts: DownloadOptions): Promise<void> {
  if (url.protocol !== "http:" && url.protocol !== "https:") {
    throw new DownloadError(`Only http and https URLs can be downloaded (got ${url.protocol}).`);
  }
  if (opts.allowPrivate) return;
  const host = url.hostname.replace(/^\[|\]$/g, "");
  let addresses: string[];
  try {
    addresses = isIP(host) ? [host] : await (opts.lookup ?? defaultLookup)(host);
  } catch {
    throw new DownloadError(`Could not find the server ${host}. Check the URL is correct.`);
  }
  if (addresses.length === 0 || addresses.some(isPrivateAddress)) {
    throw new DownloadError("That address points to a private or local network and can't be fetched.");
  }
}

// ── Filenames ────────────────────────────────────────────────────────────────

export function isPlainFilename(name: string): boolean {
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

// ── Download ─────────────────────────────────────────────────────────────────

function tooLarge(maxBytes: number): DownloadError {
  return new DownloadError(
    `File is too large to attach (limit is ${Math.round(maxBytes / 1024 / 1024)} MB). Try finding a compressed or alternative version.`
  );
}

/** Downloads a public http(s) URL, checking every redirect hop and capping the size while streaming. */
export async function download(rawUrl: string, opts: DownloadOptions = {}): Promise<Download> {
  const maxBytes = opts.maxBytes ?? MAX_BYTES;
  const doFetch = opts.fetch ?? fetch;
  const abort = new AbortController();
  const timer = setTimeout(() => abort.abort(), TIMEOUT_MS);
  try {
    let url = new URL(rawUrl);
    let response: Response;
    for (let hop = 0; ; hop++) {
      await assertPublicUrl(url, opts);
      response = await doFetch(url, { redirect: "manual", signal: abort.signal });
      const location = response.headers.get("location");
      if (response.status < 300 || response.status >= 400 || !location) break;
      if (hop === MAX_REDIRECTS) throw new DownloadError(`Too many redirects (more than ${MAX_REDIRECTS}).`);
      await response.body?.cancel();
      url = new URL(location, url);
    }

    if (!response.ok) {
      const hint =
        response.status === 403 || response.status === 401
          ? " The server is blocking automated downloads. Try finding a direct PDF link from a different source."
          : response.status === 404
          ? " The file was not found at this URL. It may have moved — try searching for an updated link."
          : "";
      throw new DownloadError(`Download failed: HTTP ${response.status} ${response.statusText}.${hint}`);
    }
    if ((response.headers.get("content-type") ?? "").startsWith("text/html")) {
      throw new DownloadError(
        "The URL returned an HTML page rather than a file. This is likely a product page or login wall, not a direct download link. Try right-clicking the download button on the page and copying the direct PDF link."
      );
    }
    if (Number(response.headers.get("content-length") ?? 0) > maxBytes) throw tooLarge(maxBytes);

    const chunks: Uint8Array[] = [];
    let total = 0;
    if (response.body) {
      const reader = response.body.getReader();
      for (;;) {
        const { done, value } = await reader.read();
        if (done) break;
        total += value.byteLength;
        if (total > maxBytes) {
          await reader.cancel();
          throw tooLarge(maxBytes);
        }
        chunks.push(value);
      }
    }
    return {
      data: Buffer.concat(chunks),
      filename: inferFilename(response.headers.get("content-disposition"), url.href),
    };
  } catch (err) {
    if (err instanceof DownloadError) throw err;
    if (abort.signal.aborted) {
      throw new DownloadError(
        `Download timed out after ${TIMEOUT_MS / 1000}s. The server may be blocking automated requests or the file is too slow to respond. Try a different direct download URL.`
      );
    }
    throw new DownloadError(
      `Network error fetching URL: ${err instanceof Error ? err.message : String(err)}. Check the URL is correct and publicly accessible.`
    );
  } finally {
    clearTimeout(timer);
  }
}
