import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { zodToJsonSchema } from "zod-to-json-schema";
import type { Backend } from "./backends/interface.js";
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

export function createServer(backend: Backend) {
  const server = new Server(
    { name: "allourthings", version: "0.1.0" },
    { capabilities: { tools: {} } }
  );

  server.setRequestHandler(ListToolsRequestSchema, async () => ({
    tools: [
      {
        name: "add_item",
        description: "Add a new item to the household inventory",
        inputSchema: zodToJsonSchema(addItemInputSchema),
      },
      {
        name: "get_item",
        description: "Get a single item by ID or name",
        inputSchema: zodToJsonSchema(getItemInputSchema),
      },
      {
        name: "list_items",
        description: "List all items, optionally filtered by category or tags",
        inputSchema: zodToJsonSchema(listItemsInputSchema),
      },
      {
        name: "update_item",
        description: "Update fields on an existing item",
        inputSchema: zodToJsonSchema(updateItemInputSchema),
      },
      {
        name: "delete_item",
        description: "Delete an item by ID",
        inputSchema: zodToJsonSchema(deleteItemInputSchema),
      },
      {
        name: "search_items",
        description: "Full-text search across all item fields",
        inputSchema: zodToJsonSchema(searchItemsInputSchema),
      },
      {
        name: "add_attachment",
        description: "Attach a file (manual, receipt, photo, warranty, etc.) to an item. File contents must be base64-encoded.",
        inputSchema: zodToJsonSchema(addAttachmentInputSchema),
      },
      {
        name: "get_attachment",
        description: "Retrieve an attachment's contents as a base64-encoded string. Useful for checking an attachment exists. Note: binary files like PDFs cannot be read or displayed directly.",
        inputSchema: zodToJsonSchema(getAttachmentInputSchema),
      },
      {
        name: "delete_attachment",
        description: "Delete an attachment from an item",
        inputSchema: zodToJsonSchema(deleteAttachmentInputSchema),
      },
      {
        name: "attach_from_url",
        description: "Download a file from a URL and attach it to an item (e.g. a PDF manual or warranty document)",
        inputSchema: zodToJsonSchema(attachFromUrlInputSchema),
      },
    ],
  }));

  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const { name, arguments: args } = request.params;

    switch (name) {
      case "add_item":
        return addItem(backend, addItemInputSchema.parse(args));
      case "get_item":
        return getItem(backend, getItemInputSchema.parse(args));
      case "list_items":
        return listItems(backend, listItemsInputSchema.parse(args));
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
      default:
        throw new Error(`Unknown tool: ${name}`);
    }
  });

  return server;
}
