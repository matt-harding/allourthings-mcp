import { readFile, writeFile, mkdir, readdir, rename, rm } from "fs/promises";
import { existsSync } from "fs";
import { join } from "path";
import { randomBytes } from "crypto";
import type { Backend } from "./interface.js";
import { ItemSchema } from "../schema.js";
import type { Item, NewItem } from "../schema.js";

function generateId(): string {
  return randomBytes(4).toString("hex");
}

function toSlug(name: string): string {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 50)
    .replace(/-+$/, "");
}

export class FilesystemBackend implements Backend {
  private dataDir: string;

  constructor(dataDir: string) {
    this.dataDir = dataDir;
  }

  private get itemsDir(): string {
    return join(this.dataDir, "items");
  }

  private itemDirPath(name: string, id: string): string {
    return join(this.itemsDir, `${toSlug(name)}-${id}`);
  }

  // Find an item's directory by its 8-char ID suffix.
  private async findDirById(id: string): Promise<string | null> {
    if (!existsSync(this.itemsDir)) return null;
    const entries = await readdir(this.itemsDir);
    const match = entries.find((e) => e.slice(-8) === id);
    return match ? join(this.itemsDir, match) : null;
  }

  private async readItemFromDir(dir: string): Promise<Item> {
    const raw = await readFile(join(dir, "item.json"), "utf-8");
    return ItemSchema.parse(JSON.parse(raw));
  }

  private async writeItemToDir(dir: string, item: Item): Promise<void> {
    await mkdir(dir, { recursive: true });
    await writeFile(join(dir, "item.json"), JSON.stringify(item, null, 2));
  }

  private async loadAll(): Promise<Item[]> {
    if (!existsSync(this.itemsDir)) return [];
    const entries = await readdir(this.itemsDir);
    const items: Item[] = [];
    for (const entry of entries) {
      const itemPath = join(this.itemsDir, entry, "item.json");
      if (!existsSync(itemPath)) continue;
      try {
        const raw = await readFile(itemPath, "utf-8");
        items.push(ItemSchema.parse(JSON.parse(raw)));
      } catch {
        // skip malformed items
      }
    }
    return items;
  }

  async addItem(newItem: NewItem): Promise<Item> {
    const id = generateId();
    const now = new Date().toISOString();
    const item: Item = { ...newItem, id, created_at: now, updated_at: now };
    await this.writeItemToDir(this.itemDirPath(item.name, id), item);
    return item;
  }

  async getItem(idOrName: string): Promise<Item | null> {
    // Try exact ID match first
    const dirById = await this.findDirById(idOrName);
    if (dirById) return this.readItemFromDir(dirById);

    // Fall back to name search
    const items = await this.loadAll();
    const lower = idOrName.toLowerCase();
    return (
      items.find((i) => i.name.toLowerCase() === lower) ??
      items.find((i) => i.name.toLowerCase().includes(lower)) ??
      null
    );
  }

  async listItems(filter?: {
    category?: string;
    location?: string;
    tags?: string[];
  }): Promise<Item[]> {
    let items = await this.loadAll();
    if (filter?.category) {
      items = items.filter((i) => i.category === filter.category);
    }
    if (filter?.location) {
      items = items.filter(
        (i) => i.location?.toLowerCase() === filter.location!.toLowerCase()
      );
    }
    if (filter?.tags?.length) {
      items = items.filter((i) =>
        filter.tags!.every((tag) => i.tags?.includes(tag))
      );
    }
    return items;
  }

  async updateItem(id: string, updates: Partial<NewItem>): Promise<Item | null> {
    const oldDir = await this.findDirById(id);
    if (!oldDir) return null;
    const existing = await this.readItemFromDir(oldDir);
    const updated: Item = {
      ...existing,
      ...updates,
      id,
      updated_at: new Date().toISOString(),
    };
    const newDir = this.itemDirPath(updated.name, id);
    if (oldDir !== newDir) {
      await rename(oldDir, newDir);
    }
    await this.writeItemToDir(newDir, updated);
    return updated;
  }

  async deleteItem(id: string): Promise<boolean> {
    const dir = await this.findDirById(id);
    if (!dir) return false;
    await rm(dir, { recursive: true });
    return true;
  }

  async searchItems(query: string): Promise<Item[]> {
    const items = await this.loadAll();
    const lower = query.toLowerCase();
    return items.filter((i) => JSON.stringify(i).toLowerCase().includes(lower));
  }
}
