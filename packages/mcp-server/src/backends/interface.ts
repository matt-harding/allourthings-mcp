import type { Item, NewItem } from "../schema.js";

export interface Backend {
  addItem(item: NewItem): Promise<Item>;
  getItem(idOrName: string): Promise<Item | null>;
  listItems(filter?: { category?: string; location?: string; tags?: string[] }): Promise<Item[]>;
  updateItem(id: string, updates: Partial<NewItem>): Promise<Item | null>;
  deleteItem(id: string): Promise<boolean>;
  searchItems(query: string): Promise<Item[]>;
}
