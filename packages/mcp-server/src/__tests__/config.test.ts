import { describe, test, expect } from "bun:test";
import { resolveDataDir } from "../config.js";
import { homedir } from "os";
import { join } from "path";

const DEFAULT = join(homedir(), "Documents", "AllOurThings");

describe("resolveDataDir", () => {
  test("returns --data-dir arg when provided", () => {
    expect(resolveDataDir(["bun", "index.ts", "--data-dir", "/custom/path"], {}))
      .toBe("/custom/path");
  });

  test("--data-dir arg takes priority over env var", () => {
    expect(resolveDataDir(
      ["bun", "index.ts", "--data-dir", "/from-arg"],
      { ALLOURTHINGS_DATA_DIR: "/from-env" }
    )).toBe("/from-arg");
  });

  test("falls back to env var when no --data-dir arg", () => {
    expect(resolveDataDir(["bun", "index.ts"], { ALLOURTHINGS_DATA_DIR: "/from-env" }))
      .toBe("/from-env");
  });

  test("falls back to default when neither arg nor env var", () => {
    expect(resolveDataDir(["bun", "index.ts"], {})).toBe(DEFAULT);
  });

  test("ignores --data-dir flag with no following value", () => {
    expect(resolveDataDir(["bun", "index.ts", "--data-dir"], {})).toBe(DEFAULT);
  });

  test("ignores unrelated args before --data-dir", () => {
    expect(resolveDataDir(["bun", "index.ts", "--verbose", "--data-dir", "/path"], {}))
      .toBe("/path");
  });
});
