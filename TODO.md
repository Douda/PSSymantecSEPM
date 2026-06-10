# PRD — SEPM API Documentation Consolidation

**Status:** Ready for implementation  
**Handoff:** This PRD is self-contained. No domain knowledge beyond what's written here is needed.

---

## What This Is

The `docs/source/` directory contains 19 OpenAPI 2.0 (Swagger) JSON files downloaded from the Broadcom SEPM API documentation portal. Together they cover the complete SEPM REST API. The goal is to process these raw files into a structured, browsable local documentation system.

## What We're Building

Three artifacts, all derived from the raw files in `docs/source/`:

| Artifact | Path | Purpose |
|----------|------|---------|
| Unified spec | `docs/OpenAPI_SEPM_full.json` | Single merged Swagger 2.0 file — the canonical reference |
| Self-contained shards | `docs/specs/<category>.json` | One file per API category, with all `$ref` dependencies resolved |
| Human-readable index | `docs/API_INDEX.md` | Markdown quick-reference: every endpoint, every schema, organized by category |

The raw files in `docs/source/` are **never modified** — they are the audit trail.

---

## Source Files

All in `docs/source/`. 19 files, 196 endpoints, 465 definitions total.

Files that need renaming (contain spaces — normalise to lowercase with underscores):

```
Group Update Provider.json          → gup.json
Threat Defense for Active Directory.json → tdad.json
Requested Files.json                → requested_files.json
```

The rest are already clean: `administrators.json`, `Blacklist.json`, `Cloud.json`, `Commands.json`, `Computers.json`, `Content.json`, `Domains.json`, `Events.json`, `Groups.json`, `Identity.json`, `Notifications.json`, `policies.json`, `Replication.json`, `Reporting.json`, `Statistics.json`, `Version.json`.

For the output filenames, use the normalised lowercased form: `blacklist.json`, `cloud.json`, `commands.json`, `computers.json`, `content.json`, `domains.json`, `events.json`, `groups.json`, `gup.json`, `identity.json`, `notifications.json`, `policies.json`, `replication.json`, `reporting.json`, `requested_files.json`, `statistics.json`, `tdad.json`, `version.json`.

### File structure (every file follows this shape)

```json
{
  "swagger": "2.0",
  "info": { "title": "...", "version": "...", "description": "..." },
  "basePath": "/sepm/api/v1",
  "schemes": ["https"],
  "paths": { "/api/v1/...": { "get|post|put|patch|delete": { ... } } },
  "definitions": { "SomeName": { "type": "object", "properties": { ... } } }
}
```

All paths share the prefix `/sepm/api/v1` (already in `basePath`). Two exceptions:
- `policies.json` has both `/api/v1/policies/...` and `/api/v2/policies/exceptions/...` paths
- `Threat Defense for Active Directory.json` uses `/api/v1/tdad/...`

---

## Step 1 — Normalise Source Filenames

Rename the three files with spaces to their normalised names (see table above). This is just a file rename — do not modify JSON content.

After this step, `docs/source/` contains 19 files with clean, lowercase (or consistently-cased) names.

---

## Step 2 — Build the Unified Spec (`docs/OpenAPI_SEPM_full.json`)

### 2a — Merge structure

Create a single Swagger 2.0 document:

```json
{
  "swagger": "2.0",
  "info": {
    "title": "Symantec Endpoint Protection Manager — Full API Reference",
    "version": "v1",
    "description": "Unified OpenAPI 2.0 specification covering all SEPM REST API endpoints. Generated from 19 category-specific specs."
  },
  "basePath": "/sepm/api/v1",
  "schemes": ["https"],
  "tags": [ ... ],
  "paths": { ... },
  "definitions": { ... }
}
```

### 2b — Merge paths

Collect all `paths` entries from every source file into one `paths` object. Path keys are unique across all source files — no collisions expected. If a collision is found (same path + same method in two files), the last one wins and emit a warning comment in the index.

### 2c — Merge definitions with deduplication

Multiple source files may define the same schema under different names or duplicate schemas under the same name. Strategy:

1. **Same name, same content** → keep one copy, skip duplicates
2. **Same name, different content** → this is a collision. Prefix the definition name with the source category (e.g., `Policies_FirewallConfiguration` vs `Groups_FirewallConfiguration`). Update **all `$ref` references** in paths and definitions accordingly.
3. **Different names, same content** → keep both. (The cost of deduplicating by content hash is higher than the cost of duplicate schemas.)

Deduplication algorithm:

```
for each source file:
    for each def_name, def_body in file.definitions:
        canonical = JSON.stringify(def_body, sorted keys)
        if def_name already seen:
            if canonical matches stored canonical → skip (duplicate)
            else → COLLISION: prefix both with category name, update $refs
        else:
            store def_name → canonical
```

After deduplication, all `$ref` values like `"$ref": "#/definitions/Foo"` must resolve to names actually present in the merged `definitions` object.

### 2d — Merge tags

Collect all unique `tags` arrays from all endpoints, deduplicate by `name`, and add a top-level `tags` array listing all unique tags.

---

## Step 3 — Shard into Self-Contained Category Files (`docs/specs/`)

For each normalised category name, produce a standalone Swagger 2.0 file containing:

- Only the paths from that category
- All definitions referenced by those paths (transitively)

### Algorithm per category

```
1. Start with the paths from the category's source file
2. Collect all $ref targets from those paths (parameters, responses, schemas)
3. For each collected definition, recursively collect its $ref targets
4. Repeat until no new definitions are discovered
5. Output the subset: paths + transitive definitions closure
```

Each shard must be valid Swagger 2.0 — every `$ref` in the shard must resolve to a definition present in that same file.

---

## Step 4 — Generate `docs/API_INDEX.md`

A single Markdown file that serves as the human-readable entry point. Structure:

### 4a — Header
- Title, base URL, total endpoint/definition counts
- Link to `docs/source/` (raw files), `docs/OpenAPI_SEPM_full.json` (unified spec), `docs/specs/` (shards)

### 4b — Endpoint Reference (grouped by category)

For each category, a section with a table:

```
## Category Name

| Method | Endpoint | Summary |
|--------|----------|---------|
| GET    | /api/v1/foo/{id} | Returns foo details |
| POST   | /api/v1/foo | Creates a new foo |
```

### 4c — Schema Reference (grouped by category)

For each category, a bullet list of definition names with their required fields:

```
### Category Name
- **`Foo`** — required: name, type
- **`Bar`** — required: id
```

Categorise definitions into the category they first appear in. Put truly shared/common definitions (like `Host`, `HostGroup`, `Page`, `Sort`, servlet types) under a "Common" section.

### 4d — Informational Notes

At the bottom of the index, note:
- Which categories have a v2 API (currently only Exceptions policy)
- That definitions with `$ref` to Java servlet types (`HttpServletRequest`, `ServletRequest`, `ServletContext`, etc.) are internal SEPM plumbing and not part of the actual API contract — they appear as parameters marked "Only used internally"
- That the `basePath` is `/sepm/api/v1` and the full URL pattern is `https://{SEPM_HOST}:{PORT}/sepm/api/v1/...`

---

## Constraints

- **Do not modify any file in `docs/source/`** except the three renames listed above. They are the audit trail.
- All processing is done via Python 3 scripts (already available in the container).
- The unified spec must be valid JSON that passes a Swagger 2.0 validator.
- Each shard must be self-contained (all `$ref` targets present in the file).
- `docs/API_INDEX.md` must render correctly as GitHub-flavored Markdown.

---

## Target Output Structure

```
docs/
├── source/                          # Raw downloads — never modified (audit trail)
│   ├── administrators.json
│   ├── blacklist.json
│   ├── cloud.json
│   ├── commands.json
│   ├── computers.json
│   ├── content.json
│   ├── domains.json
│   ├── events.json
│   ├── groups.json
│   ├── gup.json
│   ├── identity.json
│   ├── notifications.json
│   ├── policies.json
│   ├── replication.json
│   ├── reporting.json
│   ├── requested_files.json
│   ├── statistics.json
│   ├── tdad.json
│   └── version.json
├── OpenAPI_SEPM_full.json           # Unified merged spec
├── API_INDEX.md                     # Human-readable endpoint + schema reference
└── specs/                           # Self-contained shards (one per category)
    ├── administrators.json
    ├── blacklist.json
    ├── cloud.json
    ├── commands.json
    ├── computers.json
    ├── content.json
    ├── domains.json
    ├── events.json
    ├── groups.json
    ├── gup.json
    ├── identity.json
    ├── notifications.json
    ├── policies.json
    ├── replication.json
    ├── reporting.json
    ├── requested_files.json
    ├── statistics.json
    ├── tdad.json
    └── version.json
```

Existing `docs/API_INDEX.md`, `docs/OpenAPI_SEPM.json`, and `docs/specs/*` should be **deleted** before generating new output. They are stale artifacts from an earlier partial run.
