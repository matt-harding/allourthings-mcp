import { mkdtemp, rm } from "fs/promises";
import { tmpdir } from "os";
import { join } from "path";

export async function createTmpVault(): Promise<string> {
  return mkdtemp(join(tmpdir(), "allourthings-test-"));
}

export async function removeTmpVault(dir: string): Promise<void> {
  await rm(dir, { recursive: true, force: true });
}
