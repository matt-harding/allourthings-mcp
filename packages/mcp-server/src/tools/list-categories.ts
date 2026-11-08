import { z } from "zod";
import type { Backend } from "../backends/interface.js";
import { formatCategories, summariseCategories } from "../categories.js";
import { textResult } from "./result.js";

export const listCategoriesInputSchema = z.object({}).strict();

export async function listCategories(backend: Backend) {
  return textResult(formatCategories(summariseCategories(await backend.listItems())));
}
