import { describe, test, expect, beforeEach, afterEach } from "bun:test";
import { mkdtemp, rm } from "fs/promises";
import { tmpdir } from "os";
import { join } from "path";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { InMemoryTransport } from "@modelcontextprotocol/sdk/inMemory.js";
import { NativeBackend } from "../backends/native.js";
import { createServer, SERVER_VERSION } from "../server.js";
import { resolveCacheDir } from "../config.js";
import { inferFilename } from "../tools/attach-from-url.js";

type ToolResult = { content: { type: string; text: string }[]; isError?: boolean };

describe("MCP tool contract", () => {
  let dataDir: string;
  let client: Client;

  async function call(name: string, args: Record<string, unknown> = {}): Promise<ToolResult> {
    return (await client.callTool({ name, arguments: args })) as ToolResult;
  }

  async function addItem(args: Record<string, unknown>) {
    const res = await call("add_item", args);
    expect(res.isError).toBeFalsy();
    return JSON.parse(res.content[0].text) as { id: string; name: string; [k: string]: unknown };
  }

  beforeEach(async () => {
    dataDir = await mkdtemp(join(tmpdir(), "aot-server-test-"));
    const server = createServer(new NativeBackend(dataDir));
    const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
    client = new Client({ name: "test", version: "0" });
    await Promise.all([server.connect(serverTransport), client.connect(clientTransport)]);
  });

  afterEach(async () => {
    await client.close();
    await rm(dataDir, { recursive: true, force: true });
    await rm(resolveCacheDir(dataDir), { recursive: true, force: true }).catch(() => {});
  });

  test("serverInfo reports the package version", () => {
    expect(client.getServerVersion()?.version).toBe(SERVER_VERSION);
    expect(SERVER_VERSION).toMatch(/^\d+\.\d+\.\d+/);
  });

  test("invalid arguments are a tool error, not a protocol error (F7)", async () => {
    const res = await call("add_item", {});
    expect(res.isError).toBe(true);
    expect(res.content[0].text).toContain("name");
  });

  test("failed writes set isError (F6)", async () => {
    await addItem({ name: "Kettle" });
    const dup = await call("add_item", { name: "kettle" });
    expect(dup.isError).toBe(true);
    expect(dup.content[0].text).toContain("already exists");

    const badDate = await call("add_item", { name: "Toaster", purchase_date: "yesterday" });
    expect(badDate.isError).toBe(true);
  });

  test("store-managed fields are rejected (F2/F3)", async () => {
    const original = await addItem({ name: "Original Bosch" });
    const impostor = await call("add_item", { name: "Impostor", id: original.id });
    expect(impostor.isError).toBe(true);

    const rewrite = await call("update_item", { id: original.id, updates: { id: "deadbeef" } });
    expect(rewrite.isError).toBe(true);
  });

  test("unknown arguments are rejected (F8)", async () => {
    const res = await call("list_items", { location: "kitchen" });
    expect(res.isError).toBe(true);
    expect(res.content[0].text).toContain("location");
  });

  test("not-found writes are errors", async () => {
    expect((await call("delete_item", { id: "00000000" })).isError).toBe(true);
    expect((await call("update_item", { id: "00000000", updates: { notes: "x" } })).isError).toBe(true);
    expect((await call("delete_attachment", { item_id: "00000000", filename: "a.pdf" })).isError).toBe(true);
  });

  test("deleting a missing attachment is an error (F12)", async () => {
    const item = await addItem({ name: "Camera" });
    const res = await call("delete_attachment", { item_id: item.id, filename: "nope.pdf" });
    expect(res.isError).toBe(true);
  });

  test("invalid base64 and the item.json filename are rejected (F12)", async () => {
    const item = await addItem({ name: "Fridge" });
    const bad64 = await call("add_attachment", {
      item_id: item.id, filename: "a.bin", kind: "other", data_base64: "!!!not base64***",
    });
    expect(bad64.isError).toBe(true);
    expect(bad64.content[0].text).toContain("data_base64");

    const reserved = await call("add_attachment", {
      item_id: item.id, filename: "item.json", kind: "other", data_base64: "eA==",
    });
    expect(reserved.isError).toBe(true);
    expect((await call("get_attachment", { item_id: item.id, filename: "item.json" })).isError).toBe(true);

    const ok = await call("add_attachment", {
      item_id: item.id, filename: "a.bin", kind: "other", data_base64: "aGVs\nbG8=",
    });
    expect(ok.isError).toBeFalsy();
  });

  test("null clears a field via update_item (F20)", async () => {
    const item = await addItem({ name: "Router", notes: "old", serial_number: "S1" });
    const res = await call("update_item", { id: item.id, updates: { notes: null, serial_number: null } });
    expect(res.isError).toBeFalsy();
    const updated = JSON.parse(res.content[0].text);
    expect(updated.notes).toBeUndefined();
    expect(updated.serial_number).toBeUndefined();
  });

  test("ambiguous get_item lists candidates (F14)", async () => {
    const a = await addItem({ name: "Bosch Dishwasher" });
    const b = await addItem({ name: "Bosch Drill" });
    const res = await call("get_item", { id_or_name: "bosch" });
    expect(res.isError).toBe(true);
    expect(res.content[0].text).toContain(a.id);
    expect(res.content[0].text).toContain(b.id);
  });

  test("search matches values, not field names (F9)", async () => {
    await addItem({ name: "Dishwasher", brand: "Bosch" });
    expect((await call("search_items", { query: "name" })).content[0].text).toContain("No items matched");
    expect((await call("search_items", { query: "bosch" })).content[0].text).toContain("Dishwasher");
  });

  test("attach_from_url rejects a missing item before downloading (F13)", async () => {
    const res = await call("attach_from_url", {
      item_id: "00000000",
      url: "http://127.0.0.1:9/never-fetched.pdf",
      kind: "manual",
    });
    expect(res.isError).toBe(true);
    expect(res.content[0].text).toContain("No item found");
  });

  test("unknown tool is a tool error", async () => {
    expect((await call("no_such_tool")).isError).toBe(true);
  });
});

describe("inferFilename (F13)", () => {
  test("decodes percent-encoding in the URL path", () => {
    expect(inferFilename(null, "https://x.test/files/User%20Manual.pdf")).toBe("User Manual.pdf");
  });

  test("prefers Content-Disposition", () => {
    expect(inferFilename('attachment; filename="manual.pdf"', "https://x.test/download?id=1")).toBe("manual.pdf");
    expect(inferFilename("attachment; filename*=UTF-8''Gu%C3%ADa.pdf", "https://x.test/d")).toBe("Guía.pdf");
  });

  test("strips directories from header filenames", () => {
    expect(inferFilename('attachment; filename="../../etc/passwd"', "https://x.test/d")).toBe("passwd");
  });

  test("falls back to 'attachment'", () => {
    expect(inferFilename(null, "https://x.test/")).toBe("attachment");
  });
});
