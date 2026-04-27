import { z } from "zod";
import type { Backend } from "../backends/interface.js";

export const getItemFieldsInputSchema = z.object({});

export async function getItemFields(backend: Backend) {
  const fields = await backend.getItemFields();
  if (fields.length === 0) {
    return {
      content: [{ type: "text" as const, text: "No items in catalog yet." }],
    };
  }
  return {
    content: [
      {
        type: "text" as const,
        text: `Fields in use across your catalog:\n${fields.map((f) => `- ${f}`).join("\n")}`,
      },
    ],
  };
}
