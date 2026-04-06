import { z } from "zod";
import type { Backend } from "../backends/interface.js";

export const addItemInputSchema = z.object({
  name: z.string().describe("Name of the item"),
  category: z.string().optional().describe("Category (e.g. appliance, electronics, furniture, subscription)"),
  brand: z.string().optional().describe("Manufacturer or brand name"),
  model: z.string().optional().describe("Model name or number"),
  purchase_date: z.string().optional().describe("Date of purchase (ISO date, e.g. 2024-01-15)"),
  purchase_price: z.number().optional().describe("Price paid for the item"),
  currency: z.string().optional().describe("Currency code (e.g. GBP, USD, EUR)"),
  warranty_expires: z.string().optional().describe("Warranty expiry date (ISO date, e.g. 2026-01-15)"),
  retailer: z.string().optional().describe("Where the item was purchased"),
  location: z.string().optional().describe("Where the item is kept (e.g. kitchen, garage, office)"),
  features: z.array(z.string()).optional().describe("Key features or specifications"),
  notes: z.string().optional().describe("Any additional notes about the item"),
  tags: z.array(z.string()).optional().describe("Tags for grouping or searching (e.g. ['white goods', 'laundry'])"),
  serial_number: z.string().optional().describe("Serial number of the item"),
}).passthrough();

export async function addItem(
  backend: Backend,
  input: z.infer<typeof addItemInputSchema>
) {
  const item = await backend.addItem(input);
  return {
    content: [
      {
        type: "text" as const,
        text: JSON.stringify(item, null, 2),
      },
    ],
  };
}
