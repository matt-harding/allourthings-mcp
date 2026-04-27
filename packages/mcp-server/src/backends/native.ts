import { createRequire } from "module";
import type { Backend } from "./interface.js";
import type { Item, NewItem } from "../schema.js";
import { resolveCacheDir } from "../config.js";

// Load the native Rust addon (CJS module) from ESM context
const require = createRequire(import.meta.url);
const { JsCatalogStore } = require("@allourthings/core");

export class NativeBackend implements Backend {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  private store: any;

  constructor(dataDir: string) {
    this.store = new JsCatalogStore(dataDir, resolveCacheDir(dataDir));
  }

  private refresh(): void {
    try {
      this.store.refresh();
    } catch (e) {
      console.error("[allourthings] cache refresh failed:", e);
    }
  }

  async addItem(newItem: NewItem): Promise<Item> {
    return this.store.addItem(newItem) as Item;
  }

  async getItem(idOrName: string): Promise<Item | null> {
    return this.store.getItem(idOrName) as Item | null;
  }

  async listItems(filter?: {
    category?: string;
    subcategory?: string;
    tags?: string[];
  }): Promise<Item[]> {
    this.refresh();
    return this.store.listItems(filter ?? null) as Item[];
  }

  async updateItem(id: string, updates: Record<string, unknown>): Promise<Item | null> {
    return this.store.updateItem(id, updates) as Item | null;
  }

  async deleteItem(id: string): Promise<boolean> {
    return this.store.deleteItem(id) as boolean;
  }

  async searchItems(query: string): Promise<Item[]> {
    this.refresh();
    return this.store.searchItems(query) as Item[];
  }

  async getItemFields(): Promise<string[]> {
    return this.store.getItemFields() as string[];
  }

  async addAttachment(itemId: string, filename: string, kind: string, data: Buffer, label?: string): Promise<Item> {
    const result = this.store.addAttachment(itemId, filename, kind, data, label ?? null);
    if (result instanceof Error) throw result;
    return result as Item;
  }

  async getAttachment(itemId: string, filename: string): Promise<Buffer> {
    const result = this.store.getAttachment(itemId, filename);
    if (result instanceof Error) throw result;
    return result as Buffer;
  }

  async deleteAttachment(itemId: string, filename: string): Promise<Item | null> {
    const result = this.store.deleteAttachment(itemId, filename);
    if (result instanceof Error) throw result;
    return result as Item | null;
  }
}
