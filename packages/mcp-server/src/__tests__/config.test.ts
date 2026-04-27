import { describe, test, expect } from "bun:test";
import { resolveDataDir, resolveCacheDir } from "../config.js";
import { homedir, platform } from "os";
import { join } from "path";

const DEFAULT_DATA = join(homedir(), "Documents", "AllOurThings");

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
    expect(resolveDataDir(["bun", "index.ts"], {})).toBe(DEFAULT_DATA);
  });

  test("ignores --data-dir flag with no following value", () => {
    expect(resolveDataDir(["bun", "index.ts", "--data-dir"], {})).toBe(DEFAULT_DATA);
  });

  test("ignores unrelated args before --data-dir", () => {
    expect(resolveDataDir(["bun", "index.ts", "--verbose", "--data-dir", "/path"], {}))
      .toBe("/path");
  });

  test("expands ~ in --data-dir arg", () => {
    const result = resolveDataDir(["bun", "index.ts", "--data-dir", "~/Documents/AllOurThings"], {});
    expect(result).toBe(join(homedir(), "Documents/AllOurThings"));
    expect(result).not.toContain("~");
  });

  test("expands ~ in env var", () => {
    const result = resolveDataDir(["bun", "index.ts"], { ALLOURTHINGS_DATA_DIR: "~/my-vault" });
    expect(result).toBe(join(homedir(), "my-vault"));
    expect(result).not.toContain("~");
  });
});

describe("resolveCacheDir", () => {
  test("returns a path inside the platform cache directory", () => {
    const result = resolveCacheDir("/some/vault");
    if (platform() === "darwin") {
      expect(result.startsWith(join(homedir(), "Library", "Caches", "allourthings"))).toBe(true);
    } else if (platform() === "win32") {
      expect(result.toLowerCase()).toContain("allourthings");
    } else {
      expect(result.startsWith(join(homedir(), ".cache", "allourthings"))).toBe(true);
    }
  });

  test("returns a stable path for the same data dir", () => {
    expect(resolveCacheDir("/my/vault")).toBe(resolveCacheDir("/my/vault"));
  });

  test("returns different paths for different data dirs", () => {
    expect(resolveCacheDir("/vault/one")).not.toBe(resolveCacheDir("/vault/two"));
  });

  test("cache path does not contain the data dir path", () => {
    const result = resolveCacheDir("/Users/matt/Documents/AllOurThings");
    expect(result).not.toContain("Documents");
    expect(result).not.toContain("AllOurThings");
  });
});
