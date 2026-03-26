import { z } from "zod";
import type { Backend } from "../backends/interface.js";

export const addItemInputSchema = z.object({
  name: z.string().describe("Name of the item"),
  category: z.string().optional().describe("Category (e.g. appliance, furniture, subscription)"),
  brand: z.string().optional(),
  model: z.string().optional(),
  purchase_date: z.string().optional().describe("ISO date string"),
  purchase_price: z.number().optional(),
  currency: z.string().optional().describe("e.g. USD, GBP"),
  warranty_expires: z.string().optional().describe("ISO date string"),
  retailer: z.string().optional(),
  location: z.string().optional().describe("Where the item is kept"),
  features: z.array(z.string()).optional(),
  notes: z.string().optional(),
  tags: z.array(z.string()).optional(),
  manual_ref: z.string().optional().describe("URL or filename of the manual"),
  images: z.array(z.string()).optional().describe("Image file paths or URLs"),
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
