#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────────────
# Tests/bootstrap-smoke.tests.bash — Unit tests for bootstrap-smoke.sh helpers
# ────────────────────────────────────────────────────────────────────────────
#
# Tests the discover, skip, parse, and summary logic extracted from
# bootstrap-smoke.sh without requiring a live VM or SEPM instance.
#
# Usage: bash Tests/bootstrap-smoke.tests.bash
# ────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

PASS=0; FAIL=0
assert_eq() {
    local label="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  ✓ $label"
        ((PASS++)) || true
    else
        echo "  ✗ $label"
        echo "    expected: '$expected'"
        echo "    actual:   '$actual'"
        ((FAIL++)) || true
    fi
}

# ── Test 1: discover_ps7_suites — finds all run.ps7.ps1 suites ──

echo "── Test 1: discover_ps7_suites ──"

# Create mock directory structure
mkdir -p "$TEST_DIR/Scripts/Smoke/SuiteA"
mkdir -p "$TEST_DIR/Scripts/Smoke/SuiteB"
mkdir -p "$TEST_DIR/Scripts/Smoke/SuiteC"
mkdir -p "$TEST_DIR/Scripts/Smoke/Seed-SomeSeed"
mkdir -p "$TEST_DIR/Scripts/Smoke/EmptySuite"
mkdir -p "$TEST_DIR/Scripts/Smoke/OnlyPS51"

touch "$TEST_DIR/Scripts/Smoke/SuiteA/run.ps7.ps1"
touch "$TEST_DIR/Scripts/Smoke/SuiteB/run.ps7.ps1"
touch "$TEST_DIR/Scripts/Smoke/SuiteC/run.ps7.ps1"
touch "$TEST_DIR/Scripts/Smoke/Seed-SomeSeed/run.ps7.ps1"
touch "$TEST_DIR/Scripts/Smoke/OnlyPS51/run.ps51.ps1"

# SEED=0 (default) — skip Seed-* directories
SEED=0
SUITES_PS7=()
for d in "$TEST_DIR/Scripts/Smoke/"*/; do
    dirname=$(basename "$d")
    runner="${d}run.ps7.ps1"
    if [ -f "$runner" ]; then
        if [[ "$dirname" == Seed-* ]] && [ "$SEED" != "1" ]; then
            continue
        fi
        SUITES_PS7+=("$(realpath "$runner")")
    fi
done

assert_eq "finds SuiteA" "$(realpath "$TEST_DIR/Scripts/Smoke/SuiteA/run.ps7.ps1")" "${SUITES_PS7[0]:-}"
assert_eq "finds SuiteB" "$(realpath "$TEST_DIR/Scripts/Smoke/SuiteB/run.ps7.ps1")" "${SUITES_PS7[1]:-}"
assert_eq "finds SuiteC" "$(realpath "$TEST_DIR/Scripts/Smoke/SuiteC/run.ps7.ps1")" "${SUITES_PS7[2]:-}"
assert_eq "count=3 (skips Seed-* and OnlyPS51)" "3" "${#SUITES_PS7[@]}"

# SEED=1 — include Seed-* directories
SEED=1
SUITES_PS7_SEED=()
for d in "$TEST_DIR/Scripts/Smoke/"*/; do
    dirname=$(basename "$d")
    runner="${d}run.ps7.ps1"
    if [ -f "$runner" ]; then
        if [[ "$dirname" == Seed-* ]] && [ "$SEED" != "1" ]; then
            continue
        fi
        SUITES_PS7_SEED+=("$(realpath "$runner")")
    fi
done
assert_eq "SEED=1 finds 4 total (includes Seed-*)" "4" "${#SUITES_PS7_SEED[@]}"

# ── Test 2: discover_ps51_suites — finds all run.ps51.ps1 suites ──

echo "── Test 2: discover_ps51_suites ──"

SEED=0
SUITES_PS51=()
for d in "$TEST_DIR/Scripts/Smoke/"*/; do
    dirname=$(basename "$d")
    runner="${d}run.ps51.ps1"
    if [ -f "$runner" ]; then
        if [[ "$dirname" == Seed-* ]] && [ "$SEED" != "1" ]; then
            continue
        fi
        SUITES_PS51+=("$(realpath "$runner")")
    fi
done

assert_eq "finds OnlyPS51" "$(realpath "$TEST_DIR/Scripts/Smoke/OnlyPS51/run.ps51.ps1")" "${SUITES_PS51[0]:-}"
assert_eq "count=1" "1" "${#SUITES_PS51[@]}"

# ── Test 3: parse_total_line — extracts pass/fail/skip from TOTAL line ──

echo "── Test 3: parse_total_line ──"

parse_total() {
    local line="$1"
    local tests=$(echo "$line" | grep -oP '\d+(?= tests)' | head -1 || echo "0")
    local pass=$(echo "$line" | grep -oP '\d+(?= pass)' | head -1 || echo "0")
    local fail=$(echo "$line" | grep -oP '\d+(?= fail)' | head -1 || echo "0")
    local skip=$(echo "$line" | grep -oP '\d+(?= skip)' | head -1 || echo "0")
    echo "$tests $pass $fail $skip"
}

read tests pass fail skip <<< "$(parse_total "TOTAL: 5 tests, 4 pass, 1 fail, 0 skip")"
assert_eq "extracts tests=5" "5" "$tests"
assert_eq "extracts pass=4" "4" "$pass"
assert_eq "extracts fail=1" "1" "$fail"
assert_eq "extracts skip=0" "0" "$skip"

read tests pass fail skip <<< "$(parse_total "TOTAL: 10 tests, 8 pass, 0 fail, 2 skip")"
assert_eq "extracts tests=10" "10" "$tests"
assert_eq "extracts pass=8" "8" "$pass"
assert_eq "extracts fail=0" "0" "$fail"
assert_eq "extracts skip=2" "2" "$skip"

# Not a TOTAL line — should return zeros
read tests pass fail skip <<< "$(parse_total "Some random output")"
assert_eq "non-TOTAL line yields zeros" "0 0 0 0" "$tests $pass $fail $skip"

# ── Test 4: suite name extraction from runner path ──

echo "── Test 4: suite name extraction ──"

extract_suite_name() {
    local runner="$1"
    local dir_path=$(dirname "$runner")
    basename "$dir_path"
}

assert_eq "SuiteA" "SuiteA" "$(extract_suite_name "$TEST_DIR/Scripts/Smoke/SuiteA/run.ps7.ps1")"
assert_eq "Seed-SomeSeed" "Seed-SomeSeed" "$(extract_suite_name "$TEST_DIR/Scripts/Smoke/Seed-SomeSeed/run.ps7.ps1")"

# ── Test 5: SKIP_PS7 / SKIP_PS51 env vars ──

echo "── Test 5: SKIP_PS7 / SKIP_PS51 env vars ──"

SKIP_PS7=1
if [ "${SKIP_PS7:-0}" = "1" ]; then
    assert_eq "SKIP_PS7=1 triggers skip" "1" "1"
else
    assert_eq "SKIP_PS7=1 triggers skip (FAILED)" "1" "0"
fi

SKIP_PS7=0
SKIP_PS51=1
if [ "${SKIP_PS51:-0}" = "1" ]; then
    assert_eq "SKIP_PS51=1 triggers skip" "1" "1"
else
    assert_eq "SKIP_PS51=1 triggers skip (FAILED)" "1" "0"
fi

# ── Summary ──
echo ""
echo "Results: $PASS pass, $FAIL fail"
if [ "$FAIL" -gt 0 ]; then
    echo "SOME TESTS FAILED"
    exit 1
else
    echo "All tests passed."
    exit 0
fi
