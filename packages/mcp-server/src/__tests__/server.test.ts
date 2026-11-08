import { describe, test, expect, beforeEach, afterEach } from "bun:test";
import { mkdtemp, rm } from "fs/promises";
import { tmpdir } from "os";
import { join } from "path";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { InMemoryTransport } from "@modelcontextprotocol/sdk/inMemory.js";
import { NativeBackend } from "../backends/native.js";
import { createServer, SERVER_INSTRUCTIONS, SERVER_VERSION } from "../server.js";
import { resolveCacheDir } from "../config.js";
import { inferFilename } from "../download.js";
import { attachFromUrl } from "../tools/attach-from-url.js";
import { getAttachment } from "../tools/get-attachment.js";

type Content = {
  type: string;
  text: string;
  data?: string;
  mimeType?: string;
  resource?: { uri: string; mimeType: string; text?: string; blob?: string };
};
type ToolResult = { content: Content[]; isError?: boolean };

describe("MCP tool contract", () => {
  let dataDir: string;
  let backend: NativeBackend;
  let client: Client;

  async function call(name: string, args: Record<string, unknown> = {}): Promise<ToolResult> {
    const res = (await client.callTool({ name, arguments: args })) as ToolResult;
    // R5: every error path in this suite is checked for the prefix.
    if (res.isError) expect(res.content[0].text).toStartWith("Error: ");
    return res;
  }

  async function addItem(args: Record<string, unknown>) {
    const res = await call("add_item", args);
    expect(res.isError).toBeFalsy();
    return JSON.parse(res.content[0].text) as { id: string; name: string; [k: string]: unknown };
  }

  beforeEach(async () => {
    dataDir = await mkdtemp(join(tmpdir(), "aot-server-test-"));
    backend = new NativeBackend(dataDir);
    const server = createServer(backend);
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

  test("initialize returns usage instructions (R4)", () => {
    expect(client.getInstructions()).toBe(SERVER_INSTRUCTIONS);
    expect(SERVER_INSTRUCTIONS).toContain("Never invent item IDs");
  });

  test("every tool declares the agreed annotations (R1)", async () => {
    // [title, readOnly, destructive, idempotent, openWorld]
    const expected: Record<string, [string, boolean, boolean, boolean, boolean]> = {
      list_items: ["List items", true, false, true, false],
      search_items: ["Search items", true, false, true, false],
      get_item: ["Get item", true, false, true, false],
      get_item_fields: ["List fields in use", true, false, true, false],
      list_categories: ["List categories and tags", true, false, true, false],
      get_attachment: ["Get attachment", true, false, true, false],
      add_item: ["Add item", false, false, false, false],
      update_item: ["Update item", false, true, true, false],
      delete_item: ["Delete item", false, true, true, false],
      delete_attachment: ["Delete attachment", false, true, true, false],
      add_attachment: ["Add attachment", false, false, false, false],
      attach_from_url: ["Attach file from URL", false, false, false, true],
    };
    const { tools } = await client.listTools();
    const actual = Object.fromEntries(
      tools.map((t) => {
        const a = t.annotations ?? {};
        return [t.name, [a.title, a.readOnlyHint, a.destructiveHint, a.idempotentHint, a.openWorldHint]];
      })
    );
    expect(actual).toEqual(expected);
  });

  test("get_item on a missing item is not an error (R5)", async () => {
    const res = await call("get_item", { id_or_name: "00000000" });
    expect(res.isError).toBeFalsy();
    expect(res.content[0].text).not.toStartWith("Error");
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

  describe("attachments never overwrite (R2)", () => {
    async function itemWithManual() {
      const item = await addItem({ name: "Boiler" });
      const res = await call("add_attachment", {
        item_id: item.id, filename: "manual.pdf", kind: "manual", data_base64: "b3JpZ2luYWw=",
      });
      expect(res.isError).toBeFalsy();
      return item;
    }

    test("add_attachment refuses an existing filename, ignoring case", async () => {
      const item = await itemWithManual();
      for (const filename of ["manual.pdf", "Manual.PDF"]) {
        const res = await call("add_attachment", {
          item_id: item.id, filename, kind: "manual", data_base64: "bmV3",
        });
        expect(res.isError).toBe(true);
        expect(res.content[0].text).toBe(
          'Error: Boiler already has an attachment named "manual.pdf". Delete it first or choose another filename.'
        );
      }
      const kept = await call("get_attachment", { item_id: item.id, filename: "manual.pdf" });
      expect(kept.content[1].resource?.blob).toBe("b3JpZ2luYWw=");
    });

    test("attach_from_url refuses a given filename before downloading", async () => {
      const item = await itemWithManual();
      const res = await call("attach_from_url", {
        item_id: item.id, url: "http://127.0.0.1:9/never-fetched.pdf", kind: "manual", filename: "manual.pdf",
      });
      expect(res.content[0].text).toContain("already has an attachment");
    });

    test("attach_from_url refuses an inferred filename", async () => {
      const item = await itemWithManual();
      const http = Bun.serve({
        port: 0,
        fetch: () => new Response("new", { headers: { "content-type": "application/pdf" } }),
      });
      try {
        const res = await attachFromUrl(
          backend,
          { item_id: item.id, url: `http://127.0.0.1:${http.port}/manual.pdf`, kind: "manual" },
          { allowPrivate: true }
        );
        expect(res.content[0].text).toContain("already has an attachment");
      } finally {
        http.stop(true);
      }
    });
  });

  test("list_categories summarises the catalog and takes no arguments (R9)", async () => {
    expect((await call("list_categories")).content[0].text).toBe("No items in catalog yet.");
    await addItem({ name: "Oven", category: "Appliance", subcategory: "Kitchen Appliance", tags: ["white goods"] });
    await addItem({ name: "Boiler", category: "Heating" });
    expect((await call("list_categories")).content[0].text).toBe(
      "Categories:\n- Appliance (1)\n  - Kitchen Appliance (1)\n- Heating (1)\nTags:\n- white goods (1)"
    );
    expect((await call("list_categories", { category: "x" })).isError).toBe(true);
  });

  describe("get_attachment returns typed content (R10)", () => {
    async function attach(filename: string, data: string, label?: string) {
      const item = await addItem({ name: `Item for ${filename}` });
      const res = await call("add_attachment", {
        item_id: item.id, filename, kind: "photo", data_base64: Buffer.from(data).toString("base64"), label,
      });
      expect(res.isError).toBeFalsy();
      return item;
    }

    test("images are image content after a summary", async () => {
      const item = await attach("Front.JPG", "jpeg-bytes", "Front view");
      const res = await call("get_attachment", { item_id: item.id, filename: "Front.JPG" });
      expect(res.content[0]).toEqual({ type: "text", text: "Front.JPG (kind: photo, label: Front view, size: 10 B)" });
      expect(res.content[1] as unknown).toEqual({
        type: "image", data: Buffer.from("jpeg-bytes").toString("base64"), mimeType: "image/jpeg",
      });
    });

    test.each([
      ["manual.pdf", "application/pdf"],
      ["photo.heic", "application/octet-stream"],
    ])("%s is an embedded blob resource", async (filename, mimeType) => {
      const item = await attach(filename, "bytes");
      const res = await call("get_attachment", { item_id: item.id, filename });
      expect(res.content[1] as unknown).toEqual({
        type: "resource",
        resource: {
          uri: `allourthings://items/${item.id}/attachments/${filename}`,
          mimeType,
          blob: Buffer.from("bytes").toString("base64"),
        },
      });
    });

    test("text files are embedded as text with an encoded URI", async () => {
      const item = await attach("care notes.md", "# Care\nWash cold");
      const res = await call("get_attachment", { item_id: item.id, filename: "care notes.md" });
      expect(res.content[1].resource).toEqual({
        uri: `allourthings://items/${item.id}/attachments/care%20notes.md`,
        mimeType: "text/markdown",
        text: "# Care\nWash cold",
      });
    });

    test("files over the limit return only the summary", async () => {
      const item = await attach("big.pdf", "x".repeat(2048));
      const res = await getAttachment(backend, { item_id: item.id, filename: "big.pdf" }, 1024);
      expect(res.content).toHaveLength(1);
      expect((res.content[0] as { text: string }).text).toBe(
        "big.pdf (kind: photo, size: 2.0 KB)\nThis file is too large to send to the assistant (limit 1.0 KB). " +
          "It is stored in the user's vault with the item Item for big.pdf."
      );
    });
  });

  describe("ranked search (R11)", () => {
    async function seed() {
      const boiler = await addItem({ name: "Boiler", brand: "Vaillant", category: "Heating" });
      await call("add_attachment", {
        item_id: boiler.id, filename: "ecotec.pdf", kind: "manual", data_base64: "cGRm",
      });
      await addItem({ name: "Wine Fridge", category: "Appliance", subcategory: "Kitchen Appliance" });
      await addItem({ name: "Oven", category: "Appliance", subcategory: "Kitchen Appliance" });
      await addItem({ name: "Kitchen Scales", notes: "digital" });
      return boiler;
    }

    test("natural queries find items, marking those that match every word", async () => {
      const boiler = await seed();
      const res = await call("search_items", { query: "vaillant boiler manual" });
      expect(res.content[0].text).toBe(
        `1 result(s), best match first:\n- Boiler [Heating] (${boiler.id}) — all words`
      );

      const kitchen = (await call("search_items", { query: "kitchen appliances" })).content[0].text;
      const lines = kitchen.split("\n").slice(1);
      expect(lines).toHaveLength(3);
      expect(lines.slice(0, 2).every((l) => l.endsWith("— all words"))).toBe(true);
      expect(lines[2]).toStartWith("- Kitchen Scales");
      expect(lines[2]).not.toContain("all words");
    });

    test("limit caps results and says there are more", async () => {
      await seed();
      const text = (await call("search_items", { query: "kitchen", limit: 1 })).content[0].text;
      expect(text.split("\n")).toHaveLength(3);
      expect(text).toEndWith("Showing the top 1; pass a higher limit to see more.");
    });

    test("limit is validated", async () => {
      expect((await call("search_items", { query: "x", limit: 0 })).isError).toBe(true);
      expect((await call("search_items", { query: "x", limit: 101 })).isError).toBe(true);
    });
  });

  test("attach_from_url refuses local addresses (R3)", async () => {
    const item = await addItem({ name: "NAS" });
    const res = await call("attach_from_url", {
      item_id: item.id, url: "http://127.0.0.1:9/secret.pdf", kind: "other",
    });
    expect(res.content[0].text).toBe(
      "Error: That address points to a private or local network and can't be fetched."
    );
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
