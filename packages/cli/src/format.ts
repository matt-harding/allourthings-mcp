export interface Item {
  id: string;
  name: string;
  created_at: string;
  updated_at: string;
  category?: string;
  subcategory?: string;
  brand?: string;
  model?: string;
  purchase_date?: string;
  purchase_price?: number;
  currency?: string;
  warranty_expires?: string;
  retailer?: string;
  location?: string;
  serial_number?: string;
  features?: string[];
  notes?: string;
  tags?: string[];
  attachments?: Array<{ filename: string; type: string; label?: string }>;
  [key: string]: unknown;
}

function row(label: string, value: string) {
  return `  ${label.padEnd(12)}${value}`;
}

function formatDate(iso: string): string {
  return iso.split("T")[0];
}

export function formatItem(item: Item): string {
  const lines: string[] = [];

  lines.push(`${item.name} (${item.id})`);

  if (item.brand || item.model) {
    const bm = [item.brand, item.model].filter(Boolean).join(" ");
    lines.push(row("Model", bm));
  }
  if (item.category || item.subcategory) {
    const cat = [item.category, item.subcategory].filter(Boolean).join(" › ");
    lines.push(row("Category", cat));
  }
  if (item.location) lines.push(row("Location", String(item.location)));
  if (item.serial_number) lines.push(row("Serial", item.serial_number));

  if (item.purchase_date || item.purchase_price != null || item.retailer) {
    const parts: string[] = [];
    if (item.purchase_date) parts.push(formatDate(item.purchase_date));
    if (item.retailer) parts.push(`at ${item.retailer}`);
    if (item.purchase_price != null) {
      const price = `${item.purchase_price}${item.currency ? " " + item.currency : ""}`;
      parts.push(`for ${price}`);
    }
    lines.push(row("Purchased", parts.join(" ")));
  }

  if (item.warranty_expires) {
    const expiry = formatDate(item.warranty_expires);
    const expired = new Date(item.warranty_expires) < new Date();
    lines.push(row("Warranty", `${expired ? "expired" : "expires"} ${expiry}`));
  }

  if (item.tags?.length) lines.push(row("Tags", item.tags.join(", ")));
  if (item.features?.length) lines.push(row("Features", item.features.join(", ")));
  if (item.notes) lines.push(row("Notes", item.notes));

  if (item.attachments?.length) {
    const files = item.attachments
      .map((a) => (a.label ? `${a.filename} (${a.label})` : a.filename))
      .join(", ");
    lines.push(row("Files", files));
  }

  // Custom fields (passthrough — anything not in the known set)
  const known = new Set([
    "id", "name", "created_at", "updated_at", "category", "subcategory", "brand", "model",
    "purchase_date", "purchase_price", "currency", "warranty_expires", "retailer",
    "location", "serial_number", "features", "notes", "tags", "attachments",
  ]);
  for (const [key, val] of Object.entries(item)) {
    if (!known.has(key) && val != null) {
      lines.push(row(key, String(val)));
    }
  }

  lines.push(row("Added", formatDate(item.created_at)));

  return lines.join("\n");
}

export function formatItemLine(item: Item): string {
  const cat = [item.category, item.subcategory].filter(Boolean).join(" › ");
  const meta = [cat, item.location].filter(Boolean).join("  ");
  const name = item.name.padEnd(30);
  return `  ${item.id}  ${name}${meta ? `  ${meta}` : ""}`;
}

export function formatItems(items: Item[], heading?: string): string {
  if (items.length === 0) return "No items found.";
  const lines: string[] = [];
  if (heading) lines.push(heading);
  else lines.push(`${items.length} item${items.length === 1 ? "" : "s"}`);
  lines.push("");
  for (const item of items) lines.push(formatItemLine(item));
  return lines.join("\n");
}

export function out(json: boolean, text: string, data: unknown) {
  if (json) {
    process.stdout.write(JSON.stringify(data, null, 2) + "\n");
  } else {
    process.stdout.write(text + "\n");
  }
}
