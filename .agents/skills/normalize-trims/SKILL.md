---
name: normalize-trims
description: Discover and fix trim level normalization issues across all vehicle makes. Queries DB for makes, runs show_trims, categorizes near-duplicates by pattern type, and proposes YAML rules for config/vehicle_normalization.yaml. Use when user wants to normalize trim levels, clean up data quality, discover duplication patterns, or maintain vehicle_normalization.yaml.
---

# Normalize Trims

## Quick start

```bash
# Scan all makes with ≥500 vehicles
python -m src.ingestion.cli.discover_trims

# Narrower scan (≥1000 vehicles, more trims per model)
python -m src.ingestion.cli.discover_trims --min-vehicles 1000 --top-trims 15

# Filter to specific category
python -m src.ingestion.cli.discover_trims --category accent
```

## How it works

1. Queries DB for makes with ≥N vehicles
2. Runs `show_trims` CLI against each make
3. Parses near-duplicate pairs from output
4. Classifies each pair into categories

## Categories

| Category | Example | Actionable? | Action |
|----------|---------|-------------|--------|
| `case` | `"ALLURE"` / `"Allure"` | ✅ Yes | Add case rule to YAML |
| `hyphen/space` | `"ST Line"` / `"ST-Line"` | ✅ Yes | Add hyphen rule to YAML |
| `accent` | `"Elégance"` / `"Elegance"` | ✅ Yes | Add accent rule to YAML |
| `punctuation` | `"Style+"` / `"Style"` | ⚠️ Sometimes | These are often different trims — review manually |
| `suffix` | `"Style"` / `"Style II"` | ❌ No | Different generations/spin-offs, not duplicates |
| `other` | `"GT"` / `"GTI"` | ❌ No | Levenshtein false positives — genuinely different trims |

## Workflow

### 1. Discover

```bash
python -m src.ingestion.cli.discover_trims --min-vehicles 1000 --top-trims 12
```

Review the output. Focus on `case`, `hyphen/space`, and `accent` categories.

### 2. Propose YAML rules

For each actionable category, propose additions to `config/vehicle_normalization.yaml` under the appropriate `trims:` make section.

Format per make:
```yaml
MakeName:
  "Raw Variant": "Canonical Form"
```

Rules are applied AFTER prefix stripping, so keys should match the bare trim name (e.g. `"ST Line"`, not `"FORD_Fiesta_ST Line"`).

### 3. Verify rules

Test each proposed rule with the normalizer:
```python
from src.ingestion.storage.normalizer import normalize_trim, clear_config_cache
clear_config_cache()
result = normalize_trim("MakeName", "ModelName", "Raw Variant")
assert result == "Canonical Form"
```

### 4. Apply to existing data

After adding rules to the YAML, run the migration to update existing vehicles:
```bash
docker compose exec app alembic upgrade head
```

Or, if the migration already ran but new rules were added, re-run the YAML rules pass. The migration's Pass 2 (Python batch) processes all vehicles with non-NULL trim_level.

## Categories in detail

### case — Case normalization

Pure case differences. After normalization they're identical lowercase.

**Pattern**: Add both forms to the YAML, lowercased variant → title-cased canonical.

```yaml
MakeName:
  "ALLURE": "Allure"
  "allure": "Allure"
```

### hyphen/space — Hyphen vs space variants

Same words, different separator. Most common in trim lines.

**Pattern**: Normalize to the hyphenated form (industry convention).

```yaml
MakeName:
  "ST Line": "ST-Line"
  "GT Line": "GT-Line"
  "Monte Carlo": "Monte-Carlo"
```

### accent — Accent normalization

Same word with/without diacritics.

**Pattern**: Normalize to the non-accented form (search-friendly).

```yaml
MakeName:
  "Elégance": "Elegance"
  "Féline": "Feline"
  "Référence": "Reference"
```

### punctuation — Punctuation/symbol variants

`+` suffixes, `²`, `!` characters. **Review carefully** — some are genuinely different trims.

**True duplicates** (normalize):
- `"Cool Line²"` → `"Cool Line"` (same trim, weird Unicode)
- `"Cross+"` → `"Cross"` (the `+` is a display variant)

**Different trims** (do NOT normalize):
- `"Style"` vs `"Style+"` — the `+` denotes a higher spec
- `"Prestige"` vs `"Prestige +"` — different trim level

### suffix / other — False positives

The Levenshtein ≤2 detector flags these, but they're genuinely different trims. **Do not add YAML rules for these.** Examples:

- `GTD` / `GTI` — different engine variants
- `Style` / `Style II` — different generations
- `GT` / `XT` / `XS` — different trim levels

## YAML config reference

The trim normalization pipeline has three layers:

1. **YAML config** (`config/vehicle_normalization.yaml`) — editable rules
2. **Python normalizer** (`src/ingestion/storage/normalizer.py`) — `normalize_trim()` applies rules
3. **Migration** (`migrations/versions/20260527_200000_normalize_trim_levels.py`) — backfills existing data

Processing order per trim:
```
Raw: FORD_Fiesta_ST Line
  ↓ Pass 1: prefix stripping (SQL)
Bare: ST Line
  ↓ Pass 2: YAML rule lookup
Final: ST-Line
```
