import { createRequire } from "module";
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { ZodError, z } from "zod";
import type { Backend } from "./backends/interface.js";
import { errorResult } from "./tools/result.js";
import { addItem, addItemInputSchema } from "./tools/add-item.js";
import { getItem, getItemInputSchema } from "./tools/get-item.js";
import { listItems, listItemsInputSchema } from "./tools/list-items.js";
import { updateItem, updateItemInputSchema } from "./tools/update-item.js";
import { deleteItem, deleteItemInputSchema } from "./tools/delete-item.js";
import { searchItems, searchItemsInputSchema } from "./tools/search-items.js";
import { addAttachment, addAttachmentInputSchema } from "./tools/add-attachment.js";
import { getAttachment, getAttachmentInputSchema } from "./tools/get-attachment.js";
import { deleteAttachment, deleteAttachmentInputSchema } from "./tools/delete-attachment.js";
import { attachFromUrl, attachFromUrlInputSchema } from "./tools/attach-from-url.js";
import { getItemFields, getItemFieldsInputSchema } from "./tools/get-item-fields.js";
import { listCategories, listCategoriesInputSchema } from "./tools/list-categories.js";

// src/ and dist/ both sit one level below package.json.
export const SERVER_VERSION: string = createRequire(import.meta.url)("../package.json").version;

export const SERVER_INSTRUCTIONS = `AllOurThings is the user's personal inventory, stored in a folder on their own device. Nothing is sent to AllOurThings servers.
- Use search_items for open questions and list_items with filters for structured lookups. Call get_item_fields to see which fields this catalog uses before adding or updating items.
- Search matches words, not meanings. If a search finds nothing, try other words (e.g. "fridge" for "refrigerator") or use list_categories / list_items and judge the results yourself.
- Never invent item IDs. Use IDs returned by the tools. If a name matches several items, ask the user which one.
- Confirm with the user before deleting items or attachments, or clearing fields.
- attach_from_url downloads from the internet. Only use URLs from the manufacturer or another trustworthy source, prefer direct PDF links, and pass a readable filename.
- Dates are YYYY-MM-DD; prices are plain numbers with a separate currency.`;

function toInputSchema(schema: z.ZodType) {
  return z.toJSONSchema(schema, { io: "input" }) as { type: "object"; [key: string]: unknown };
}

const READ = { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false };
const WRITE = { readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: false };
const DESTRUCTIVE = { readOnlyHint: false, destructiveHint: true, idempotentHint: true, openWorldHint: false };

function describeError(err: unknown): string {
  if (err instanceof ZodError) {
    const issues = err.issues.map((i) => {
      const path = i.path.join(".");
      return path ? `${path}: ${i.message}` : i.message;
    });
    return `Invalid arguments: ${issues.join("; ")}`;
  }
  return err instanceof Error ? err.message : String(err);
}

export function createServer(backend: Backend) {
  const server = new Server(
    { name: "allourthings", version: SERVER_VERSION },
    { capabilities: { tools: {} }, instructions: SERVER_INSTRUCTIONS }
  );

  server.setRequestHandler(ListToolsRequestSchema, async () => ({
    tools: [
      {
        name: "add_item",
        description: "Add a new item to the inventory. Names must be unique. Custom fields are accepted alongside the listed ones; id, created_at, updated_at and attachments are managed automatically.",
        inputSchema: toInputSchema(addItemInputSchema),
        annotations: { title: "Add item", ...WRITE },
      },
      {
        name: "get_item",
        description: "Get a single item by ID or name. If a name matches several items, an error lists their IDs.",
        inputSchema: toInputSchema(getItemInputSchema),
        annotations: { title: "Get item", ...READ },
      },
      {
        name: "list_items",
        description: "List all items, optionally filtered by category, subcategory, or tags",
        inputSchema: toInputSchema(listItemsInputSchema),
        annotations: { title: "List items", ...READ },
      },
      {
        name: "update_item",
        description: "Update fields on an existing item. Set a field to null to clear it. id, created_at, updated_at and attachments cannot be changed here.",
        inputSchema: toInputSchema(updateItemInputSchema),
        // Destructive: overwrites values, and null clears a field.
        annotations: { title: "Update item", ...DESTRUCTIVE },
      },
      {
        name: "delete_item",
        description: "Delete an item by ID",
        inputSchema: toInputSchema(deleteItemInputSchema),
        annotations: { title: "Delete item", ...DESTRUCTIVE },
      },
      {
        name: "search_items",
        description: "Search item field values (case-insensitive). Every word in the query must appear in some field.",
        inputSchema: toInputSchema(searchItemsInputSchema),
        annotations: { title: "Search items", ...READ },
      },
      {
        name: "add_attachment",
        description: "Attach a file (manual, receipt, photo, warranty, etc.) to an item. File contents must be base64-encoded. Never replaces an existing attachment with the same filename.",
        inputSchema: toInputSchema(addAttachmentInputSchema),
        annotations: { title: "Add attachment", ...WRITE },
      },
      {
        name: "get_attachment",
        description: "Retrieve an attachment so you can view or read it. Images are returned as images, PDFs and other files as embedded resources, and text files as text, after a short summary (filename, kind, label, size). Files over 10 MB are not sent; only the summary is returned.",
        inputSchema: toInputSchema(getAttachmentInputSchema),
        annotations: { title: "Get attachment", ...READ },
      },
      {
        name: "delete_attachment",
        description: "Delete an attachment from an item",
        inputSchema: toInputSchema(deleteAttachmentInputSchema),
        annotations: { title: "Delete attachment", ...DESTRUCTIVE },
      },
      {
        name: "attach_from_url",
        description: "Download a file from the public internet and attach it to an item (e.g. a PDF manual or warranty document). Only the downloaded file is stored, in the user's local vault. Private and local network addresses are refused. Never replaces an existing attachment with the same filename.",
        inputSchema: toInputSchema(attachFromUrlInputSchema),
        annotations: { title: "Attach file from URL", ...WRITE, openWorldHint: true },
      },
      {
        name: "get_item_fields",
        description: "Return all field names currently in use across your catalog. Call this before adding or updating items to discover what fields exist and use consistent naming.",
        inputSchema: toInputSchema(getItemFieldsInputSchema),
        annotations: { title: "List fields in use", ...READ },
      },
      {
        name: "list_categories",
        description: "Show how the catalog is organised: categories with their subcategories, and tags, each with item counts. Call this before adding or recategorising items, and reuse the existing spelling rather than inventing near-duplicates.",
        inputSchema: toInputSchema(listCategoriesInputSchema),
        annotations: { title: "List categories and tags", ...READ },
      },
    ],
  }));

  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const { name, arguments: args } = request.params;
    try {
      return await callTool(backend, name, args);
    } catch (err) {
      return errorResult(describeError(err));
    }
  });

  return server;
}

async function callTool(backend: Backend, name: string, args: unknown) {
  switch (name) {
    case "add_item":
      return addItem(backend, addItemInputSchema.parse(args));
    case "get_item":
      return getItem(backend, getItemInputSchema.parse(args));
    case "list_items":
      return listItems(backend, listItemsInputSchema.parse(args ?? {}));
    case "update_item":
      return updateItem(backend, updateItemInputSchema.parse(args));
    case "delete_item":
      return deleteItem(backend, deleteItemInputSchema.parse(args));
    case "search_items":
      return searchItems(backend, searchItemsInputSchema.parse(args));
    case "add_attachment":
      return addAttachment(backend, addAttachmentInputSchema.parse(args));
    case "get_attachment":
      return getAttachment(backend, getAttachmentInputSchema.parse(args));
    case "delete_attachment":
      return deleteAttachment(backend, deleteAttachmentInputSchema.parse(args));
    case "attach_from_url":
      return attachFromUrl(backend, attachFromUrlInputSchema.parse(args));
    case "get_item_fields":
      getItemFieldsInputSchema.parse(args ?? {});
      return getItemFields(backend);
    case "list_categories":
      listCategoriesInputSchema.parse(args ?? {});
      return listCategories(backend);
    default:
      return errorResult(`Unknown tool: ${name}`);
  }
}
