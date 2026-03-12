import { z } from "zod";

export const ItemSchema = z
  .object({
    id: z.string(),
    name: z.string(),
    created_at: z.string().datetime(),
    updated_at: z.string().datetime(),
    // Well-known optional fields
    category: z.string().optional(),
    brand: z.string().optional(),
    model: z.string().optional(),
    purchase_date: z.string().optional(),
    purchase_price: z.number().optional(),
    currency: z.string().optional(),
    warranty_expires: z.string().optional(),
    retailer: z.string().optional(),
    location: z.string().optional(),
    features: z.array(z.string()).optional(),
    notes: z.string().optional(),
    tags: z.array(z.string()).optional(),
    manual_ref: z.string().optional(),
    images: z.array(z.string()).optional(),
  })
  .passthrough(); // allow user-defined custom fields

export type Item = z.infer<typeof ItemSchema>;

export const NewItemSchema = ItemSchema.omit({
  id: true,
  created_at: true,
  updated_at: true,
}).passthrough();

export type NewItem = z.infer<typeof NewItemSchema>;
