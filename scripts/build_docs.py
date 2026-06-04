#!/usr/bin/env python3
"""Build SEPM API documentation artifacts from raw OpenAPI 2.0 source files.

Usage:
    python3 scripts/build_docs.py normalize   # Step 1: Rename files with spaces
    python3 scripts/build_docs.py merge       # Step 2: Unified spec
    python3 scripts/build_docs.py shard       # Step 3: Self-contained shards
    python3 scripts/build_docs.py index       # Step 4: Human-readable index
    python3 scripts/build_docs.py all         # Clean stale + run all steps
"""

import json
import os
import re
import shutil
import sys
from collections import OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE_DIR = ROOT / "docs" / "source"
OUTPUT_DIR = ROOT / "docs"
SPECS_DIR = OUTPUT_DIR / "specs"
UNIFIED_PATH = OUTPUT_DIR / "OpenAPI_SEPM_full.json"
INDEX_PATH = OUTPUT_DIR / "API_INDEX.md"

RENAME_MAP = {
    "Group Update Provider.json": "gup.json",
    "Threat Defense for Active Directory.json": "tdad.json",
    "Requested Files.json": "requested_files.json",
}


# ---------------------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------------------

def canonical_json(obj):
    """Return a canonical (sorted-keys) JSON string for deduplication."""
    return json.dumps(obj, sort_keys=True, ensure_ascii=True)


def find_ref_targets(obj):
    """Return a set of definition names referenced via $ref in obj."""
    targets = set()

    def _walk(o):
        if isinstance(o, dict):
            if "$ref" in o and isinstance(o["$ref"], str):
                ref = o["$ref"]
                if ref.startswith("#/definitions/"):
                    targets.add(ref.split("/")[-1])
            for v in o.values():
                _walk(v)
        elif isinstance(o, list):
            for item in o:
                _walk(item)

    _walk(obj)
    return targets


def rewrite_refs(obj, rename_map):
    """Replace $ref targets according to rename_map (old_name -> new_name)."""
    if isinstance(obj, dict):
        if "$ref" in obj and isinstance(obj["$ref"], str):
            ref = obj["$ref"]
            if ref.startswith("#/definitions/"):
                old_name = ref.split("/")[-1]
                if old_name in rename_map:
                    obj = dict(obj)  # shallow copy to avoid mutating original
                    obj["$ref"] = f"#/definitions/{rename_map[old_name]}"
        return {k: rewrite_refs(v, rename_map) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [rewrite_refs(item, rename_map) for item in obj]
    return obj


def load_json(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def save_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")


def category_from_filename(fname):
    """Normalised category name from filename (e.g. 'gup.json' -> 'gup')."""
    return Path(fname).stem.lower()


def source_files():
    """Yield (filename, data) for JSON files in SOURCE_DIR, sorted."""
    for fname in sorted(os.listdir(SOURCE_DIR)):
        if fname.endswith(".json"):
            yield fname, load_json(SOURCE_DIR / fname)


# ---------------------------------------------------------------------------
# Step 1 — Normalise source filenames
# ---------------------------------------------------------------------------

def cmd_normalize():
    """Rename files containing spaces to normalised lowercase names."""
    renamed = 0
    for old_name, new_name in RENAME_MAP.items():
        old_path = SOURCE_DIR / old_name
        new_path = SOURCE_DIR / new_name
        if old_path.exists():
            if new_path.exists():
                print(f"WARNING: target {new_name} already exists, skipping {old_name}")
                continue
            old_path.rename(new_path)
            print(f"  {old_name} -> {new_name}")
            renamed += 1
        elif new_path.exists():
            pass  # already renamed in a previous run
        else:
            print(f"WARNING: source file {old_name} not found")
    print(f"Renamed {renamed} file(s).")


# ---------------------------------------------------------------------------
# Step 2 — Build unified spec
# ---------------------------------------------------------------------------

def cmd_merge():
    """Merge all source files into docs/OpenAPI_SEPM_full.json."""
    # --- Phase 1: Analyse definitions across all files ---
    # def_registry: def_name -> { canonical_str: [file1, file2, ...] }
    def_registry = {}
    # file_defs: filename -> { def_name: canonical_str }
    file_defs = {}

    for fname, data in source_files():
        file_defs[fname] = {}
        for dname, dbody in data.get("definitions", {}).items():
            canon = canonical_json(dbody)
            file_defs[fname][dname] = canon
            def_registry.setdefault(dname, {}).setdefault(canon, []).append(fname)

    # Identify collisions (same name, different canonicals)
    collisions = {}
    for dname, variants in def_registry.items():
        if len(variants) > 1:
            collisions[dname] = variants

    # Build per-file rename maps for collisions
    # For each collision, assign a prefix to each variant group
    file_rename_map = {}  # fname -> { old_def_name: new_def_name }

    for dname, variants in collisions.items():
        for canon, files in variants.items():
            prefix = category_from_filename(files[0])
            new_name = f"{prefix}_{dname}"
            for fname in files:
                file_rename_map.setdefault(fname, {})[dname] = new_name

    # Phase 1b: identify identical duplicates for dedup tracking
    # Files where a def is an identical duplicate (skip when merging)
    identical_dup_files = {}  # def_name -> [files to skip (not first)]
    for dname, variants in def_registry.items():
        if len(variants) == 1:  # single canonical, possibly multiple files
            canon, files = next(iter(variants.items()))
            if len(files) > 1 and dname not in collisions:
                # First file keeps it, rest skip
                identical_dup_files[dname] = files[1:]

    # --- Phase 2: Merge paths ---
    merged_paths = OrderedDict()
    path_collisions = []

    for fname, data in source_files():
        rename = file_rename_map.get(fname, {})
        for path_key, path_methods in data.get("paths", {}).items():
            for method in path_methods:
                method = method.lower()
                if path_key in merged_paths and method in merged_paths[path_key]:
                    path_collisions.append(f"{method.upper()} {path_key} (last in {fname})")
                    print(f"WARNING: path collision — {method.upper()} {path_key}")
            # Apply rename map to all $refs in paths
            rewritten = rewrite_refs(path_methods, rename)
            if path_key not in merged_paths:
                merged_paths[path_key] = OrderedDict()
            merged_paths[path_key].update(rewritten)

    # --- Phase 3: Merge definitions ---
    merged_defs = OrderedDict()
    skipped_dupes = 0
    collision_renames = 0

    for fname, data in source_files():
        rename = file_rename_map.get(fname, {})
        for dname, dbody in data.get("definitions", {}).items():
            new_name = rename.get(dname, dname)  # apply collision rename if any

            # Rewrite internal $refs before making any decisions
            rewritten = rewrite_refs(dbody, rename)

            # Check if this is an identical duplicate we should skip
            if dname in identical_dup_files and fname in identical_dup_files[dname]:
                skipped_dupes += 1
                continue

            # Check if we already have this definition
            if new_name in merged_defs:
                # Verify the content matches (compare rewritten bodies)
                canon_new = canonical_json(rewritten)
                canon_existing = canonical_json(merged_defs[new_name])
                if canon_new != canon_existing:
                    print(f"ERROR: collision rename conflict for {new_name} in {fname}")
                    sys.exit(1)
                continue

            merged_defs[new_name] = rewritten
            if new_name != dname:
                collision_renames += 1

    # --- Phase 4: Merge tags ---
    all_tags = OrderedDict()
    for fname, data in source_files():
        for tag in data.get("tags", []):
            all_tags[tag["name"]] = tag

    # --- Phase 5: Build output ---
    unified = OrderedDict()
    unified["swagger"] = "2.0"
    unified["info"] = {
        "title": "Symantec Endpoint Protection Manager — Full API Reference",
        "version": "v1",
        "description": (
            "Unified OpenAPI 2.0 specification covering all SEPM REST API endpoints. "
            "Generated from 19 category-specific specs."
        ),
    }
    unified["basePath"] = "/sepm/api/v1"
    unified["schemes"] = ["https"]
    unified["tags"] = list(all_tags.values())
    unified["paths"] = merged_paths
    unified["definitions"] = merged_defs

    save_json(UNIFIED_PATH, unified)

    # --- Report ---
    total_paths = sum(len(methods) for methods in merged_paths.values())
    print(f"Unified spec written to {UNIFIED_PATH}")
    print(f"  Endpoints: {total_paths}")
    print(f"  Definitions: {len(merged_defs)}")
    print(f"  Collisions renamed: {collision_renames}")
    print(f"  Duplicate definitions skipped: {skipped_dupes}")
    if path_collisions:
        print(f"  Path collisions: {len(path_collisions)}")


# ---------------------------------------------------------------------------
# Step 3 — Shard into self-contained category files
# ---------------------------------------------------------------------------

def cmd_shard():
    """Generate self-contained Swagger 2.0 files per category in docs/specs/."""
    unified = load_json(UNIFIED_PATH)
    all_defs = unified.get("definitions", {})
    all_paths = unified.get("paths", {})

    # Group paths by category (first segment after /api/v1/)
    category_paths = {}
    for path_key, methods in all_paths.items():
        # Extract category from path, e.g. /api/v1/computers/... -> computers
        # Handle /api/v1/version (no sub-path) -> version
        # Handle /api/v2/policies/exceptions/... -> policies
        segments = path_key.strip("/").split("/")
        if len(segments) >= 3 and segments[0] == "api":
            if segments[1] in ("v1", "v2"):
                category = segments[2]
            else:
                category = segments[1]
        else:
            category = "other"
        category_paths.setdefault(category, OrderedDict())[path_key] = methods

    # Map category to source filename for naming
    # We need to know which categories exist from source files
    src_categories = {}
    for fname, _ in source_files():
        cat = category_from_filename(fname)
        src_categories[cat] = fname

    # For each category, find transitive definition closure
    SPECS_DIR.mkdir(parents=True, exist_ok=True)
    count = 0

    for category, paths in sorted(category_paths.items()):
        # Collect all $ref targets from paths
        needed = set()
        for path_methods in paths.values():
            needed |= find_ref_targets(path_methods)

        # Transitive closure: collect refs from needed defs
        queue = list(needed)
        while queue:
            dname = queue.pop()
            if dname not in all_defs:
                continue
            dbody = all_defs[dname]
            sub_refs = find_ref_targets(dbody)
            for ref in sub_refs:
                if ref not in needed:
                    needed.add(ref)
                    queue.append(ref)

        # Build shard
        shard_defs = OrderedDict()
        for dname in sorted(needed):
            if dname in all_defs:
                shard_defs[dname] = all_defs[dname]

        shard = OrderedDict()
        shard["swagger"] = "2.0"
        shard["info"] = {
            "title": f"SEPM {category.upper()} API",
            "version": "v1",
            "description": f"Self-contained OpenAPI 2.0 specification for SEPM {category} endpoints.",
        }
        shard["basePath"] = "/sepm/api/v1"
        shard["schemes"] = ["https"]
        shard["paths"] = paths
        if shard_defs:
            shard["definitions"] = shard_defs

        # Determine output filename from source mapping or category name
        out_name = f"{category}.json"
        save_json(SPECS_DIR / out_name, shard)
        count += 1

    print(f"Generated {count} shard(s) in {SPECS_DIR}")


# ---------------------------------------------------------------------------
# Step 4 — Generate API_INDEX.md
# ---------------------------------------------------------------------------

def cmd_index():
    """Generate docs/API_INDEX.md — human-readable endpoint and schema reference."""
    unified = load_json(UNIFIED_PATH)
    all_paths = unified.get("paths", {})
    all_defs = unified.get("definitions", {})

    # Group paths by category
    category_paths = {}
    for path_key, methods in all_paths.items():
        segments = path_key.strip("/").split("/")
        if len(segments) >= 3 and segments[0] == "api":
            if segments[1] in ("v1", "v2"):
                category = segments[2]
            else:
                category = segments[1]
        else:
            category = "other"
        category_paths.setdefault(category, OrderedDict())[path_key] = methods

    # Figure out which definitions belong to which category based on first
    # $ref usage, or fall back to name prefix
    def_category = {}  # def_name -> category

    # Collect source categories for collision-rename prefix resolution
    src_categories = {}
    for fname, _ in source_files():
        src_categories[category_from_filename(fname)] = fname

    # Heuristic: if def name starts with a category prefix (from collisions),
    # assign to that category
    for fname, data in source_files():
        cat = category_from_filename(fname)
        for dname in data.get("definitions", {}):
            if dname not in def_category:
                def_category[dname] = cat

    # Map collision-renamed definitions back to source categories
    # e.g. blacklist_HttpServletRequest -> blacklist (or Common for servlet types)
    for dname in all_defs:
        if dname not in def_category:
            # Check if name has a known category prefix
            parts = dname.split("_", 1)
            if len(parts) == 2 and parts[0] in src_categories:
                def_category[dname] = parts[0]

    # Identify servlet/internal types
    servlet_patterns = [
        "HttpServletRequest", "HttpServletResponse", "HttpSession",
        "HttpSessionContext", "ServletContext", "ServletInputStream",
        "ServletOutputStream", "ServletRequest", "ServletResponse",
        "BufferedReader", "Cookie", "Enumeration", "Locale", "Principal",
        "PrintWriter", "StringBuffer", "FilterRegistration",
        "HttpServletMapping", "SessionCookieConfig", "ServletRegistration",
        "JspConfigDescriptor", "JspPropertyGroupDescriptor", "TaglibDescriptor",
        "Annotation", "AsyncContext", "ClassLoader", "EnumerationLocale",
        "EnumerationServlet", "EnumerationString", "InputStream", "Module",
        "ModuleDescriptor", "ModuleLayer", "Package", "Part",
    ]

    # Build Markdown
    lines = []
    lines.append("# SEPM API Reference")
    lines.append("")
    lines.append("**Source:** Symantec Endpoint Protection Manager API Reference v1  ")
    lines.append(f"**Base URL:** `https://{{SEPM_HOST}}:{{PORT}}/sepm/api/v1`  ")

    total_endpoints = sum(len(methods) for methods in all_paths.values())
    total_defs = len(all_defs)
    num_categories = len(category_paths)
    lines.append(
        f"**Endpoints:** {total_endpoints} | **Definitions:** {total_defs} | **Categories:** {num_categories}  "
    )
    lines.append("")
    lines.append(f"- [Raw source files](source/) — downloaded from Broadcom SEPM API portal")
    lines.append(f"- [Unified spec](OpenAPI_SEPM_full.json) — single merged Swagger 2.0 file")
    lines.append(f"- [Spec shards](specs/) — self-contained files per category")
    lines.append("")
    lines.append("---")
    lines.append("")
    lines.append("## Endpoints")
    lines.append("")

    for category in sorted(category_paths):
        paths = category_paths[category]
        lines.append(f"### {category}")
        lines.append("")
        lines.append("| Method | Endpoint | Summary |")
        lines.append("|--------|----------|---------|")
        for path_key in paths:
            for method, details in sorted(paths[path_key].items()):
                if method in ("parameters",):
                    continue
                summary = details.get("summary", "").replace("|", "\\|")
                lines.append(f"| {method.upper():6s} | `{path_key}` | {summary} |")
        lines.append("")

    lines.append("---")
    lines.append("")
    lines.append("## Schemas")
    lines.append("")

    # Group defs by category
    cat_defs = {}
    common_defs = []
    # Also match collision-prefixed servlet types (e.g. blacklist_HttpServletRequest)
    servlet_base = set(servlet_patterns)
    servlet_base.update(["Page", "Sort"])

    for dname, dbody in sorted(all_defs.items()):
        # Check if it's a servlet/internal type (even with collision prefix)
        base_name = dname
        for prefix in src_categories:
            if dname.startswith(f"{prefix}_"):
                base_name = dname[len(prefix) + 1:]
                break
        if base_name in servlet_base:
            common_defs.append(dname)
            continue
        # Check common utility types
        if base_name in ("Host", "HostGroup", "HostGroupSummary",
                          "PageObject", "PageCommandStatusDetail",
                          "PageHostGroupSummary", "HostConfiguration",
                          "GroupSummary"):
            common_defs.append(dname)
            continue
        cat = def_category.get(dname, "other")
        cat_defs.setdefault(cat, []).append(dname)

    for category in sorted(cat_defs):
        lines.append(f"### {category}")
        lines.append("")
        for dname in sorted(cat_defs[category]):
            dbody = all_defs.get(dname, {})
            required = dbody.get("required", [])
            req_str = ", ".join(required) if required else "none"
            lines.append(f"- **`{dname}`** — required: {req_str}")
        lines.append("")

    if common_defs:
        lines.append("### Common")
        lines.append("")
        for dname in sorted(common_defs):
            dbody = all_defs.get(dname, {})
            required = dbody.get("required", [])
            req_str = ", ".join(required) if required else "none"
            lines.append(f"- **`{dname}`** — required: {req_str}")
        lines.append("")

    lines.append("---")
    lines.append("")
    lines.append("## Notes")
    lines.append("")

    # Check which categories have v2 paths
    v2_categories = set()
    for path_key in all_paths:
        if "/api/v2/" in path_key:
            segments = path_key.strip("/").split("/")
            if len(segments) >= 3:
                v2_categories.add(segments[2])

    if v2_categories:
        lines.append(f"- Categories with **v2 API** paths: {', '.join(sorted(v2_categories))}")
        lines.append("")

    lines.append(
        "- Definitions referencing Java servlet types (`HttpServletRequest`, `ServletRequest`, "
        "`ServletContext`, etc.) are internal SEPM plumbing and **not part of the actual API contract**. "
        "They appear as parameters marked \"Only used internally\"."
    )
    lines.append(
        f"- The `basePath` is `/sepm/api/v1` and the full URL pattern is "
        f"`https://{{SEPM_HOST}}:{{PORT}}/sepm/api/v1/...`"
    )
    lines.append("")

    INDEX_PATH.write_text("\n".join(lines), encoding="utf-8")
    print(f"Index written to {INDEX_PATH}")


# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------

def clean_stale():
    """Remove stale artifacts from previous runs."""
    # Also remove the old unified spec name (previously OpenAPI_SEPM.json)
    old_unified = OUTPUT_DIR / "OpenAPI_SEPM.json"
    for path in [UNIFIED_PATH, INDEX_PATH, old_unified]:
        if path.exists():
            path.unlink()
            print(f"  Removed {path}")
    if SPECS_DIR.exists():
        shutil.rmtree(SPECS_DIR)
        print(f"  Removed {SPECS_DIR}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == "all":
        print("=== Cleaning stale artifacts ===")
        clean_stale()
        print("\n=== Step 1: Normalise source filenames ===")
        cmd_normalize()
        print("\n=== Step 2: Merge into unified spec ===")
        cmd_merge()
        print("\n=== Step 3: Shard into category files ===")
        cmd_shard()
        print("\n=== Step 4: Generate API index ===")
        cmd_index()
        print("\nDone.")
    elif cmd == "normalize":
        cmd_normalize()
    elif cmd == "merge":
        cmd_merge()
    elif cmd == "shard":
        cmd_shard()
    elif cmd == "index":
        cmd_index()
    elif cmd == "clean":
        clean_stale()
    else:
        print(f"Unknown command: {cmd}")
        print(__doc__)
        sys.exit(1)


if __name__ == "__main__":
    main()
