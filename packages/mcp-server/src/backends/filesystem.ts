import { readFile, writeFile, mkdir } from "fs/promises";
import { existsSync } from "fs";
import { join, dirname } from "path";
import { randomUUID } from "crypto";
import type { Backend } from "./interface.js";
import { ItemSchema } from "../schema.js";
import type { Item, NewItem } from "../schema.js";

export class FilesystemBackend implements Backend {
  private catalogPath: string;

  constructor(catalogPath: string) {
    this.catalogPath = catalogPath;
  }

  private async load(): Promise<Item[]> {
    if (!existsSync(this.catalogPath)) return [];
    const raw = await readFile(this.catalogPath, "utf-8");
    const parsed = JSON.parse(raw);
    return parsed.map((item: unknown) => ItemSchema.parse(item));
  }

  private async save(items: Item[]): Promise<void> {
    await mkdir(dirname(this.catalogPath), { recursive: true });
    await writeFile(this.catalogPath, JSON.stringify(items, null, 2));
  }

  async addItem(newItem: NewItem): Promise<Item> {
    const items = await this.load();
    const now = new Date().toISOString();
    const item: Item = {
      ...newItem,
      id: randomUUID(),
      created_at: now,
      updated_at: now,
    };
    items.push(item);
    await this.save(items);
    return item;
  }

  async getItem(idOrName: string): Promise<Item | null> {
    const items = await this.load();
    return (
      items.find(
        (item) =>
          item.id === idOrName ||
          item.name.toLowerCase() === idOrName.toLowerCase()
      ) ?? null
    );
  }

  async listItems(filter?: {
    category?: string;
    tags?: string[];
  }): Promise<Item[]> {
    let items = await this.load();
    if (filter?.category) {
      items = items.filter((item) => item.category === filter.category);
    }
    if (filter?.tags?.length) {
      items = items.filter((item) =>
        filter.tags!.every((tag) => item.tags?.includes(tag))
      );
    }
    return items;
  }

  async updateItem(
    id: string,
    updates: Partial<NewItem>
  ): Promise<Item | null> {
    const items = await this.load();
    const index = items.findIndex((item) => item.id === id);
    if (index === -1) return null;
    items[index] = {
      ...items[index],
      ...updates,
      id,
      updated_at: new Date().toISOString(),
    };
    await this.save(items);
    return items[index];
  }

  async deleteItem(id: string): Promise<boolean> {
    const items = await this.load();
    const filtered = items.filter((item) => item.id !== id);
    if (filtered.length === items.length) return false;
    await this.save(filtered);
    return true;
  }

  async searchItems(query: string): Promise<Item[]> {
    const items = await this.load();
    const lower = query.toLowerCase();
    return items.filter((item) =>
      JSON.stringify(item).toLowerCase().includes(lower)
    );
  }
}
