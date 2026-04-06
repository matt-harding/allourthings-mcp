import { describe, test, expect, beforeEach, afterEach } from "bun:test";
import { mkdtemp, rm } from "fs/promises";
import { tmpdir } from "os";
import { join } from "path";
import { NativeBackend } from "../backends/native.js";

describe("attachment tools", () => {
  let dataDir: string;
  let backend: NativeBackend;

  beforeEach(async () => {
    dataDir = await mkdtemp(join(tmpdir(), "aot-test-"));
    backend = new NativeBackend(dataDir);
  });

  afterEach(async () => {
    await rm(dataDir, { recursive: true, force: true });
  });

  test("add_attachment writes file and records metadata on item", async () => {
    const item = await backend.addItem({ name: "Bosch Washing Machine" });
    const data = Buffer.from("%PDF-1.4 fake manual content");

    const updated = await backend.addAttachment(item.id, "manual.pdf", "manual", data, "User Manual");

    expect(updated.attachments).toHaveLength(1);
    expect(updated.attachments![0].filename).toBe("manual.pdf");
    expect(updated.attachments![0].type).toBe("manual");
    expect(updated.attachments![0].label).toBe("User Manual");
  });

  test("get_attachment returns exact bytes that were stored", async () => {
    const item = await backend.addItem({ name: "Test Item" });
    const data = Buffer.from("exact binary content \x00\x01\x02");

    await backend.addAttachment(item.id, "receipt.jpg", "receipt", data);

    const retrieved = await backend.getAttachment(item.id, "receipt.jpg");
    expect(Buffer.compare(retrieved, data)).toBe(0);
  });

  test("delete_attachment removes file and clears metadata", async () => {
    const item = await backend.addItem({ name: "Test Item" });
    await backend.addAttachment(item.id, "warranty.pdf", "warranty", Buffer.from("warranty doc"));

    const afterDelete = await backend.deleteAttachment(item.id, "warranty.pdf");

    const attachments = afterDelete?.attachments ?? [];
    expect(attachments.filter((a: { filename: string }) => a.filename === "warranty.pdf")).toHaveLength(0);
    await expect(backend.getAttachment(item.id, "warranty.pdf")).rejects.toThrow();
  });

  test("multiple attachment kinds coexist on one item", async () => {
    const item = await backend.addItem({ name: "Samsung TV" });

    await backend.addAttachment(item.id, "manual.pdf", "manual", Buffer.from("manual"), "Manual");
    await backend.addAttachment(item.id, "receipt.pdf", "receipt", Buffer.from("receipt"), "Receipt");
    const updated = await backend.addAttachment(item.id, "warranty.pdf", "warranty", Buffer.from("warranty"), "Warranty");

    expect(updated.attachments).toHaveLength(3);
    const types = updated.attachments!.map((a: { type: string }) => a.type);
    expect(types).toContain("manual");
    expect(types).toContain("receipt");
    expect(types).toContain("warranty");
  });

  test("re-adding same filename replaces content", async () => {
    const item = await backend.addItem({ name: "Test Item" });

    await backend.addAttachment(item.id, "doc.pdf", "manual", Buffer.from("version 1"));
    await backend.addAttachment(item.id, "doc.pdf", "manual", Buffer.from("version 2"));

    const retrieved = await backend.getAttachment(item.id, "doc.pdf");
    expect(retrieved.toString()).toBe("version 2");
  });

  test("add_attachment without label stores attachment with no label", async () => {
    const item = await backend.addItem({ name: "Test Item" });
    const updated = await backend.addAttachment(item.id, "photo.jpg", "photo", Buffer.from("img"));

    expect(updated.attachments![0].label).toBeUndefined();
  });

  test("get_attachment on missing file throws", async () => {
    const item = await backend.addItem({ name: "Test Item" });
    await expect(backend.getAttachment(item.id, "nonexistent.pdf")).rejects.toThrow();
  });
});
