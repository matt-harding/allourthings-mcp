import { describe, test, expect, beforeEach, afterEach } from "bun:test";
import { mkdtemp, rm, writeFile, readFile } from "fs/promises";
import { tmpdir } from "os";
import { join } from "path";
import { fitWidth } from "../format.js";

const CLI = join(import.meta.dir, "..", "index.ts");

let home: string;
let vault: string;

function cli(args: string[], stdin?: string) {
  const proc = Bun.spawnSync([process.execPath, CLI, "--data-dir", vault, ...args], {
    env: { ...process.env, HOME: home, ALLOURTHINGS_DATA_DIR: "" },
    stdin: stdin === undefined ? "ignore" : Buffer.from(stdin),
    cwd: home,
  });
  return { code: proc.exitCode, stdout: proc.stdout.toString(), stderr: proc.stderr.toString() };
}

function addJson(args: string[]) {
  const res = cli(["--json", "add", ...args]);
  expect(res.code).toBe(0);
  return JSON.parse(res.stdout) as { id: string; [k: string]: unknown };
}

beforeEach(async () => {
  home = await mkdtemp(join(tmpdir(), "aot-cli-home-"));
  vault = join(home, "vault");
});

afterEach(async () => {
  await rm(home, { recursive: true, force: true });
});

describe("errors are clean, never stack traces (F4/F5)", () => {
  test("attach to a missing item fails", async () => {
    const file = join(home, "manual.pdf");
    await writeFile(file, "pdf");
    const res = cli(["attach", "add", "deadbeef", file]);
    expect(res.code).toBe(1);
    expect(res.stderr).toBe("error: item not found: deadbeef\n");
  });

  test("attach get of a missing file fails", () => {
    const item = addJson(["Camera"]);
    const res = cli(["attach", "get", item.id, "nope.pdf"]);
    expect(res.code).toBe(1);
    expect(res.stderr).toStartWith("error: attachment not found");
  });

  test("--set with typed well-known fields does not crash", () => {
    const item = addJson(["Router"]);
    const res = cli(["--json", "update", item.id, "--set", "tags=a, b", "--set", "purchase_price=12"]);
    expect(res.code).toBe(0);
    const updated = JSON.parse(res.stdout);
    expect(updated.tags).toEqual(["a", "b"]);
    expect(updated.purchase_price).toBe(12);
  });

  test("--json errors are JSON on stderr (F19)", () => {
    const res = cli(["--json", "get", "nothing-here"]);
    expect(res.code).toBe(1);
    expect(JSON.parse(res.stderr)).toEqual({ error: "no item found: nothing-here" });
  });
});

describe("input validation (F11)", () => {
  test.each([["Infinity"], ["0x10"], ["-5"], ["abc"]])("rejects --price %s", (price) => {
    const res = cli(["add", "Thing", "--price", price]);
    expect(res.code).toBe(1);
    expect(res.stderr).toContain("price must be a non-negative decimal");
  });

  test("rejects an empty --price on add instead of dropping it", () => {
    expect(cli(["add", "Thing", "--price", ""]).code).toBe(1);
  });

  test("rejects invalid dates and empty names", () => {
    expect(cli(["add", "D1", "--purchase-date", "yesterday"]).code).toBe(1);
    expect(cli(["add", ""]).code).toBe(1);
  });

  test("rejects an empty --set key", () => {
    const item = addJson(["Lamp"]);
    const res = cli(["update", item.id, "--set", "=value"]);
    expect(res.code).toBe(1);
    expect(res.stderr).toContain("non-empty key");
  });
});

describe("clearing fields (F20)", () => {
  test("--unset and empty values clear fields", () => {
    const item = addJson(["Kettle", "--notes", "old", "--brand", "Smeg"]);
    const res = cli(["--json", "update", item.id, "--unset", "notes", "--brand", ""]);
    expect(res.code).toBe(0);
    const updated = JSON.parse(res.stdout);
    expect(updated.notes).toBeUndefined();
    expect(updated.brand).toBeUndefined();
  });
});

describe("delete confirmation (F18)", () => {
  test("accepts 'yes'", () => {
    const item = addJson(["Toaster"]);
    const res = cli(["delete", item.id], "yes\n");
    expect(res.code).toBe(0);
    expect(res.stdout).toContain("Deleted item");
  });

  test("a declined prompt exits non-zero and keeps the item", () => {
    const item = addJson(["Blender"]);
    const res = cli(["delete", item.id], "n\n");
    expect(res.code).toBe(1);
    expect(res.stderr).toBe("error: cancelled\n");
    expect(cli(["get", item.id]).code).toBe(0);
  });

  test("end of input without an answer is an error", () => {
    const item = addJson(["Mixer"]);
    const res = cli(["delete", item.id], "");
    expect(res.code).toBe(1);
    expect(res.stderr).toContain("pass --yes");
    expect(cli(["get", item.id]).code).toBe(0);
  });
});

describe("attach get output (F19)", () => {
  test("-o - writes to stdout and --json reports the saved file", async () => {
    const item = addJson(["Oven"]);
    const file = join(home, "manual.pdf");
    await writeFile(file, "manual-bytes");
    expect(cli(["attach", "add", item.id, file]).code).toBe(0);

    expect(cli(["attach", "get", item.id, "manual.pdf", "-o", "-"]).stdout).toBe("manual-bytes");

    const dest = join(home, "copy.pdf");
    const res = cli(["--json", "attach", "get", item.id, "manual.pdf", "-o", dest]);
    expect(JSON.parse(res.stdout)).toEqual({ saved: dest, bytes: 12 });
    expect(await readFile(dest, "utf8")).toBe("manual-bytes");
  });
});

describe("attach url (F13)", () => {
  test("rejects a missing item before downloading", () => {
    const res = cli(["attach", "url", "deadbeef", "http://127.0.0.1:9/never.pdf"]);
    expect(res.code).toBe(1);
    expect(res.stderr).toBe("error: no item found with id: deadbeef\n");
  });
});

describe("human output (F17)", () => {
  test("brand and model are labelled separately; long keys stay readable", () => {
    const item = addJson(["Dishwasher", "--brand", "Bosch", "--model", "SMS6"]);
    cli(["update", item.id, "--set", "energy_rating=A++"]);
    const res = cli(["get", item.id]);
    expect(res.stdout).toContain("  Brand       Bosch\n");
    expect(res.stdout).toContain("  Model       SMS6\n");
    expect(res.stdout).toContain("energy_rating A++");
  });

  test("fitWidth truncates and aligns by display width", () => {
    expect(fitWidth("abc", 5)).toBe("abc  ");
    expect(fitWidth("abcdefgh", 5)).toBe("abcd…");
    expect(fitWidth("日本語", 7)).toBe("日本語 ");
    expect(fitWidth("日本語テキスト", 7)).toBe("日本語…");
  });
});
