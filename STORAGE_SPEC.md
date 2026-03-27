# AllOurThings Storage Specification

This document is the **canonical definition** of how AllOurThings data is stored on disk.
Every client (MCP server, iOS app, Android app, or any future implementation) must conform
to this spec. When the spec and an implementation conflict, the spec wins.

The MCP server TypeScript implementation is the reference implementation.

---

## 1. Catalog directory layout

```
<catalog-dir>/
  items/
    <slug>-<id>/
      item.json
```

- `<catalog-dir>` is user-configured (e.g. `~/Documents/AllOurThings`, an iCloud Drive folder,
  a Dropbox folder, etc.).
- The `items/` subdirectory is created automatically on first write if it does not exist.
- Each item occupies its own subdirectory named `<slug>-<id>` (see §3 and §4).
- Item data lives in a file named exactly `item.json` inside that subdirectory.
- The subdirectory may contain other files in future (e.g. `images/`, attachments). Readers
  must not assume `item.json` is the only file present.

---

## 2. Reading rules

Readers **must**:
- Enumerate only direct children of `items/` that are directories.
- Skip hidden entries (names beginning with `.`).
- Skip any directory that does not contain `item.json`.
- Silently skip any `item.json` that is not valid JSON or fails schema validation — do not
  surface an error to the user.
- Return an empty list (not an error) when `items/` does not exist.

Readers **must not**:
- Assume any ordering of items on disk.
- Depend on JSON key ordering within `item.json`.

---

## 3. Item ID format

```
4 cryptographically random bytes, hex-encoded lowercase = 8 characters
```

Examples: `a1b2c3d4`, `deadbeef`, `00ff1234`

IDs are generated at item creation time and never change, even if the item is renamed.

**Lookup by ID:** scan `items/` directory entries for one whose name ends with `-<id>`.
This means the slug portion is ignored during lookup — only the trailing `-<id>` suffix
is used. This is intentional: it allows the directory to be renamed (on item rename)
without breaking ID-based lookups.

---

## 4. Slug algorithm

The slug forms the human-readable prefix of the directory name.

```
slug(name):
  1. Lowercase the entire string
  2. Replace one or more consecutive non-[a-z0-9] characters with a single "-"
  3. Strip leading and trailing "-"
  4. Truncate to 50 characters
  5. Strip any trailing "-" introduced by truncation
```

### Reference implementation (TypeScript)

```typescript
function toSlug(name: string): string {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 50)
    .replace(/-+$/, "");
}
```

### Test vectors

| Input | Output |
|---|---|
| `"Bosch Washing Machine"` | `"bosch-washing-machine"` |
| `"PlayStation 5"` | `"playstation-5"` |
| `"100% Wool Blanket"` | `"100-wool-blanket"` |
| `"  Spaces  "` | `"spaces"` |
| `"A & B -- C"` | `"a-b-c"` |
| `"MacBook Pro 14\""` | `"macbook-pro-14"` |
| `"A very long name that exceeds fifty characters totally"` | `"a-very-long-name-that-exceeds-fifty-characters-tot"` |

Any implementation of `toSlug` must produce identical output to the TypeScript reference
for all inputs, including the test vectors above.

---

## 5. Item schema

All fields use **snake_case** JSON keys.

### Required fields

| Field | Type | Description |
|---|---|---|
| `id` | `string` | 8 lowercase hex chars (§3) |
| `name` | `string` | Human-readable item name |
| `created_at` | `string` | ISO 8601 datetime with milliseconds, e.g. `"2026-03-27T10:00:00.000Z"` |
| `updated_at` | `string` | ISO 8601 datetime with milliseconds, updated on every write |

### Well-known optional fields

| Field | Type | Description |
|---|---|---|
| `category` | `string` | e.g. `"appliance"`, `"electronics"` |
| `brand` | `string` | Manufacturer name |
| `model` | `string` | Model number or name |
| `purchase_date` | `string` | Date-only ISO 8601, e.g. `"2025-02-10"` — **not** a full datetime |
| `purchase_price` | `number` | Numeric value (not a string) |
| `currency` | `string` | ISO 4217 code, e.g. `"GBP"`, `"USD"` |
| `warranty_expires` | `string` | Date-only ISO 8601, e.g. `"2027-02-10"` — **not** a full datetime |
| `retailer` | `string` | Where it was purchased |
| `location` | `string` | Physical location, e.g. `"kitchen"`, `"office"` |
| `features` | `string[]` | List of notable features |
| `notes` | `string` | Free-form notes |
| `tags` | `string[]` | User-defined tags |
| `attachments` | `Attachment[]` | References to associated files (see §6) |

### Passthrough / custom fields

Any additional fields not listed above **must be preserved** through read/write round-trips.
Implementations must not strip unknown fields. This allows Claude (or future tools) to
annotate items with arbitrary structured data.

Example: an item with `"serial_number": "C02XG0Y1JGH7"` must retain that field after
being read and written by any conforming client.

---

## 6. Attachment schema

Attachments reference files associated with an item (manuals, receipts, photos, warranties).

```json
{
  "filename": "manual.pdf",
  "type": "manual",
  "label": "User Guide"
}
```

| Field | Type | Required | Values |
|---|---|---|---|
| `filename` | `string` | yes | Filename relative to the item directory |
| `type` | `string` | yes | `"manual"`, `"receipt"`, `"photo"`, `"warranty"`, `"other"` |
| `label` | `string` | no | Human-readable description |

---

## 7. File format

- Encoding: **UTF-8**
- Format: **JSON** (no comments, no trailing commas)
- Pretty-printing: 2-space indent is conventional but readers must not require it
- Key ordering: **not guaranteed** — readers must not depend on key order

---

## 8. Write rules

Writers **must**:
- Set `updated_at` to the current UTC time on every write.
- Set `created_at` at item creation time and **never change it** thereafter.
- Write atomically where possible (write to a temp file, then rename).
- Create `items/` and the item subdirectory if they do not exist.
- Rename the item directory when the item's name changes (slug changes), preserving the
  `-<id>` suffix so ID-based lookup continues to work.

Writers **must not**:
- Strip fields they do not recognise.
- Change `id` or `created_at` after creation.

---

## 9. Conformance test fixture

The directory `test-fixtures/catalog/` in this repository is a pre-built catalog that all
client implementations must be able to read correctly.

Expected behaviour against the fixture:

| Assertion | Expected |
|---|---|
| Items returned by list | 3 |
| Items silently skipped (malformed) | 1 |
| `id` of minimal item | `00000001` |
| `id` of full item | `00000002` |
| `id` of custom-fields item | `00000003` |
| Custom field `serial_number` on item `00000003` | `"ABC123XYZ"` |
| `purchase_price` on full item | `649` (number, not string) |
| `purchase_date` on full item | `"2025-02-10"` (date-only, not datetime) |

See `test-fixtures/MANIFEST.json` for the machine-readable version of these assertions.

---

## 10. Known inconsistencies and open issues

| Issue | Status |
|---|---|
| iOS `Item` model encodes `purchaseDate`/`warrantyExpires` as full ISO 8601 datetimes instead of date-only strings | Bug — iOS should encode as `YYYY-MM-DD` |
| iOS schema has `images: [String]?` and `manualRef: String?`; MCP server uses `attachments: [Attachment]` | To be resolved — see backlog story "Align item schema: attachments vs images/manual_ref" |
