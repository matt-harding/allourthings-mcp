import { describe, test, expect, beforeAll, afterAll } from "bun:test";
import { download, isPrivateAddress } from "../download.js";

const PRIVATE_MSG = "That address points to a private or local network and can't be fetched.";
const PUBLIC_IP = "93.184.216.34";

let hits = 0;
let http: ReturnType<typeof Bun.serve>;
let local: string;

beforeAll(() => {
  http = Bun.serve({
    port: 0,
    fetch(req) {
      hits++;
      const path = new URL(req.url).pathname;
      if (path === "/stream") {
        // No Content-Length: the size cap must apply while streaming.
        let sent = 0;
        return new Response(
          new ReadableStream({
            pull(controller) {
              if (sent >= 10) return controller.close();
              sent++;
              controller.enqueue(new Uint8Array(1000));
            },
          }),
          { headers: { "content-type": "application/pdf" } }
        );
      }
      if (path === "/big") return new Response("x".repeat(100), { headers: { "content-type": "application/pdf" } });
      if (path === "/page") return new Response("<html>", { headers: { "content-type": "text/html" } });
      return new Response("pdf-bytes", { headers: { "content-type": "application/pdf" } });
    },
  });
  local = `http://127.0.0.1:${http.port}`;
});

afterAll(() => http.stop(true));

describe("isPrivateAddress (R3)", () => {
  test.each([
    "127.0.0.1", "127.255.255.254", "10.1.2.3", "172.16.0.1", "172.31.255.255", "192.168.1.1",
    "169.254.169.254", "100.64.0.1", "0.0.0.0", "255.255.255.255", "224.0.0.1",
    "::", "::1", "fc00::1", "fd12:3456::1", "fe80::1", "ff02::1",
    "::ffff:127.0.0.1", "::ffff:7f00:1", "::ffff:10.0.0.1", "::ffff:169.254.169.254",
  ])("blocks %s", (ip) => {
    expect(isPrivateAddress(ip)).toBe(true);
  });

  test.each(["8.8.8.8", "1.1.1.1", "172.32.0.1", "100.128.0.1", "2606:4700::1111", "::ffff:8.8.8.8"])(
    "allows %s",
    (ip) => {
      expect(isPrivateAddress(ip)).toBe(false);
    }
  );
});

describe("download (R3)", () => {
  test.each([
    () => `${local}/a.pdf`,
    () => `http://localhost:${http.port}/a.pdf`,
    () => `http://[::1]:${http.port}/a.pdf`,
    () => `http://[::ffff:127.0.0.1]:${http.port}/a.pdf`,
    () => `http://0x7f.1:${http.port}/a.pdf`,
  ])("refuses loopback before any request (%#)", async (url) => {
    const before = hits;
    await expect(download(url())).rejects.toThrow(PRIVATE_MSG);
    expect(hits).toBe(before);
  });

  test("refuses private and metadata addresses", async () => {
    await expect(download("http://10.0.0.1/a.pdf")).rejects.toThrow(PRIVATE_MSG);
    await expect(download("http://169.254.169.254/latest/meta-data/")).rejects.toThrow(PRIVATE_MSG);
  });

  test("refuses a hostname if any resolved address is private", async () => {
    const lookup = async () => [PUBLIC_IP, "10.0.0.5"];
    await expect(download("http://files.example/a.pdf", { lookup })).rejects.toThrow(PRIVATE_MSG);
  });

  test("refuses non-http schemes", async () => {
    await expect(download("file:///etc/passwd")).rejects.toThrow("Only http and https");
    await expect(download("ftp://files.example/a.pdf")).rejects.toThrow("Only http and https");
  });

  test("re-checks every redirect hop, so redirect-to-loopback never reaches it", async () => {
    const before = hits;
    const lookup = async () => [PUBLIC_IP];
    const fetch = (async () =>
      new Response(null, { status: 302, headers: { location: `${local}/secret` } })) as unknown as typeof globalThis.fetch;
    await expect(download("http://files.example/manual.pdf", { lookup, fetch })).rejects.toThrow(PRIVATE_MSG);
    expect(hits).toBe(before);
  });

  test("follows public redirects and names the file from the final URL", async () => {
    const lookup = async () => [PUBLIC_IP];
    const fetch = (async (url: URL) =>
      url.pathname === "/start"
        ? new Response(null, { status: 301, headers: { location: "/files/Boiler%20Manual.pdf" } })
        : new Response("pdf", { headers: { "content-type": "application/pdf" } })) as unknown as typeof globalThis.fetch;
    const res = await download("https://files.example/start", { lookup, fetch });
    expect(res.filename).toBe("Boiler Manual.pdf");
    expect(res.data.toString()).toBe("pdf");
  });

  test("stops after 5 redirects", async () => {
    const lookup = async () => [PUBLIC_IP];
    let calls = 0;
    const fetch = (async () => {
      calls++;
      return new Response(null, { status: 302, headers: { location: `/hop${calls}` } });
    }) as unknown as typeof globalThis.fetch;
    await expect(download("https://files.example/start", { lookup, fetch })).rejects.toThrow("Too many redirects");
    expect(calls).toBe(6);
  });

  test("caps the size while streaming when there is no Content-Length", async () => {
    await expect(download(`${local}/stream`, { allowPrivate: true, maxBytes: 5000 })).rejects.toThrow("too large");
  });

  test("rejects an oversized Content-Length up front", async () => {
    await expect(download(`${local}/big`, { allowPrivate: true, maxBytes: 10 })).rejects.toThrow("too large");
  });

  test("still rejects HTML pages", async () => {
    await expect(download(`${local}/page`, { allowPrivate: true })).rejects.toThrow("HTML page");
  });

  test("downloads a file", async () => {
    const res = await download(`${local}/files/manual.pdf`, { allowPrivate: true });
    expect(res.data.toString()).toBe("pdf-bytes");
    expect(res.filename).toBe("manual.pdf");
  });
});
