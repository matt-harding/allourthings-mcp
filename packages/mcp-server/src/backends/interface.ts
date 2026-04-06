import type { Item, NewItem } from "../schema.js";

export interface Backend {
  addItem(item: NewItem): Promise<Item>;
  getItem(idOrName: string): Promise<Item | null>;
  listItems(filter?: { category?: string; location?: string; tags?: string[] }): Promise<Item[]>;
  updateItem(id: string, updates: Partial<NewItem>): Promise<Item | null>;
  deleteItem(id: string): Promise<boolean>;
  searchItems(query: string): Promise<Item[]>;
  addAttachment(itemId: string, filename: string, kind: string, data: Buffer, label?: string): Promise<Item>;
  getAttachment(itemId: string, filename: string): Promise<Buffer>;
  deleteAttachment(itemId: string, filename: string): Promise<Item | null>;
}
