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

// src/ and dist/ both sit one level below package.json.
export const SERVER_VERSION: string = createRequire(import.meta.url)("../package.json").version;

function toInputSchema(schema: z.ZodType) {
  return z.toJSONSchema(schema, { io: "input" }) as { type: "object"; [key: string]: unknown };
}

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
    { capabilities: { tools: {} } }
  );

  server.setRequestHandler(ListToolsRequestSchema, async () => ({
    tools: [
      {
        name: "add_item",
        description: "Add a new item to the inventory. Names must be unique. Custom fields are accepted alongside the listed ones; id, created_at, updated_at and attachments are managed automatically.",
        inputSchema: toInputSchema(addItemInputSchema),
      },
      {
        name: "get_item",
        description: "Get a single item by ID or name. If a name matches several items, an error lists their IDs.",
        inputSchema: toInputSchema(getItemInputSchema),
      },
      {
        name: "list_items",
        description: "List all items, optionally filtered by category, subcategory, or tags",
        inputSchema: toInputSchema(listItemsInputSchema),
      },
      {
        name: "update_item",
        description: "Update fields on an existing item. Set a field to null to clear it. id, created_at, updated_at and attachments cannot be changed here.",
        inputSchema: toInputSchema(updateItemInputSchema),
      },
      {
        name: "delete_item",
        description: "Delete an item by ID",
        inputSchema: toInputSchema(deleteItemInputSchema),
      },
      {
        name: "search_items",
        description: "Search item field values (case-insensitive). Every word in the query must appear in some field.",
        inputSchema: toInputSchema(searchItemsInputSchema),
      },
      {
        name: "add_attachment",
        description: "Attach a file (manual, receipt, photo, warranty, etc.) to an item. File contents must be base64-encoded.",
        inputSchema: toInputSchema(addAttachmentInputSchema),
      },
      {
        name: "get_attachment",
        description: "Retrieve an attachment's contents as a base64-encoded string. Useful for checking an attachment exists. Note: binary files like PDFs cannot be read or displayed directly.",
        inputSchema: toInputSchema(getAttachmentInputSchema),
      },
      {
        name: "delete_attachment",
        description: "Delete an attachment from an item",
        inputSchema: toInputSchema(deleteAttachmentInputSchema),
      },
      {
        name: "attach_from_url",
        description: "Download a file from a URL and attach it to an item (e.g. a PDF manual or warranty document)",
        inputSchema: toInputSchema(attachFromUrlInputSchema),
      },
      {
        name: "get_item_fields",
        description: "Return all field names currently in use across your catalog. Call this before adding or updating items to discover what fields exist and use consistent naming.",
        inputSchema: toInputSchema(getItemFieldsInputSchema),
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
    default:
      return errorResult(`Unknown tool: ${name}`);
  }
}
