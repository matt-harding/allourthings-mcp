import type { Item, NewItem } from "../schema.js";

export interface SearchHit {
  item: Item;
  matchedAll: boolean;
}

export interface Backend {
  addItem(item: NewItem): Promise<Item>;
  getItem(idOrName: string): Promise<Item | null>;
  listItems(filter?: { category?: string; subcategory?: string; tags?: string[] }): Promise<Item[]>;
  updateItem(id: string, updates: Record<string, unknown>): Promise<Item | null>;
  deleteItem(id: string): Promise<boolean>;
  /** Ranked full-text search, best match first. */
  search(query: string, limit?: number): Promise<SearchHit[]>;
  getItemFields(): Promise<string[]>;
  addAttachment(itemId: string, filename: string, kind: string, data: Buffer, label?: string): Promise<Item>;
  getAttachment(itemId: string, filename: string): Promise<Buffer>;
  deleteAttachment(itemId: string, filename: string): Promise<Item | null>;
}
