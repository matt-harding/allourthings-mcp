import { describe, test, expect } from "bun:test";
import { resolveDataDir, resolveCacheDir, platformConfigPath } from "../config.js";
import { homedir, platform } from "os";
import { join } from "path";

const noConfig = () => null;
const fromConfig = (path: string) => () => path;

describe("resolveDataDir", () => {
  test("returns --data-dir arg when provided", () => {
    expect(resolveDataDir(["bun", "index.ts", "--data-dir", "/custom/path"], {}, noConfig))
      .toBe("/custom/path");
  });

  test("--data-dir arg takes priority over env var", () => {
    expect(resolveDataDir(
      ["bun", "index.ts", "--data-dir", "/from-arg"],
      { ALLOURTHINGS_DATA_DIR: "/from-env" },
      noConfig
    )).toBe("/from-arg");
  });

  test("--data-dir arg takes priority over config file", () => {
    expect(resolveDataDir(
      ["bun", "index.ts", "--data-dir", "/from-arg"],
      {},
      fromConfig("/from-config")
    )).toBe("/from-arg");
  });

  test("falls back to env var when no --data-dir arg", () => {
    expect(resolveDataDir(["bun", "index.ts"], { ALLOURTHINGS_DATA_DIR: "/from-env" }, noConfig))
      .toBe("/from-env");
  });

  test("env var takes priority over config file", () => {
    expect(resolveDataDir(
      ["bun", "index.ts"],
      { ALLOURTHINGS_DATA_DIR: "/from-env" },
      fromConfig("/from-config")
    )).toBe("/from-env");
  });

  test("falls back to config file when no arg or env var", () => {
    expect(resolveDataDir(["bun", "index.ts"], {}, fromConfig("/from-config")))
      .toBe("/from-config");
  });

  test("throws when nothing is configured", () => {
    expect(() => resolveDataDir(["bun", "index.ts"], {}, noConfig))
      .toThrow("No vault configured");
  });

  test("throws when --data-dir flag has no following value", () => {
    expect(() => resolveDataDir(["bun", "index.ts", "--data-dir"], {}, noConfig))
      .toThrow("No vault configured");
  });

  test("ignores unrelated args before --data-dir", () => {
    expect(resolveDataDir(["bun", "index.ts", "--verbose", "--data-dir", "/path"], {}, noConfig))
      .toBe("/path");
  });

  test("expands ~ in --data-dir arg", () => {
    const result = resolveDataDir(["bun", "index.ts", "--data-dir", "~/my-vault"], {}, noConfig);
    expect(result).toBe(join(homedir(), "my-vault"));
    expect(result).not.toContain("~");
  });

  test("expands ~ in env var", () => {
    const result = resolveDataDir(["bun", "index.ts"], { ALLOURTHINGS_DATA_DIR: "~/my-vault" }, noConfig);
    expect(result).toBe(join(homedir(), "my-vault"));
    expect(result).not.toContain("~");
  });

  test("expands ~ in config file value", () => {
    const result = resolveDataDir(["bun", "index.ts"], {}, fromConfig("~/my-vault"));
    expect(result).toBe(join(homedir(), "my-vault"));
    expect(result).not.toContain("~");
  });
});

describe("platformConfigPath", () => {
  test("returns a path ending in allourthings/config.json", () => {
    expect(platformConfigPath()).toMatch(/allourthings[/\\]config\.json$/);
  });

  test("returns a platform-appropriate path", () => {
    const p = platformConfigPath();
    if (platform() === "darwin") {
      expect(p).toContain("Application Support");
    } else if (platform() === "win32") {
      expect(p.toLowerCase()).toContain("appdata");
    } else {
      expect(p).toContain(".config");
    }
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
