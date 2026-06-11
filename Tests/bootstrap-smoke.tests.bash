#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────────────
# Tests/bootstrap-smoke.tests.bash — Unit tests for bootstrap-smoke.sh helpers
# ────────────────────────────────────────────────────────────────────────────
#
# Tests the discover, parse, and summary functions from bootstrap-smoke.sh
# without requiring a live VM or SEPM instance.
#
# Usage: bash Tests/bootstrap-smoke.tests.bash
# ────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# Source shared functions from bootstrap-smoke.sh (stops after function defs)
source "${REPO_ROOT}/Scripts/bootstrap-smoke.sh"

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

# ── Test 1: discover_smoke_suites (PS7 runners) ──

echo "── Test 1: discover_smoke_suites (PS7) ──"

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
mapfile -t SUITES_PS7 < <(discover_smoke_suites "$TEST_DIR/Scripts/Smoke" "run.ps7.ps1" 0)
assert_eq "finds SuiteA"   "$TEST_DIR/Scripts/Smoke/SuiteA/run.ps7.ps1"       "${SUITES_PS7[0]:-}"
assert_eq "finds SuiteB"   "$TEST_DIR/Scripts/Smoke/SuiteB/run.ps7.ps1"       "${SUITES_PS7[1]:-}"
assert_eq "finds SuiteC"   "$TEST_DIR/Scripts/Smoke/SuiteC/run.ps7.ps1"       "${SUITES_PS7[2]:-}"
assert_eq "count=3"        "3"                                                "${#SUITES_PS7[@]}"

# SEED=1 — include Seed-* directories
mapfile -t SUITES_PS7_SEED < <(discover_smoke_suites "$TEST_DIR/Scripts/Smoke" "run.ps7.ps1" 1)
assert_eq "SEED=1 count=4" "4" "${#SUITES_PS7_SEED[@]}"

# ── Test 2: discover_smoke_suites (PS51 runners) ──

echo "── Test 2: discover_smoke_suites (PS51) ──"

mapfile -t SUITES_PS51 < <(discover_smoke_suites "$TEST_DIR/Scripts/Smoke" "run.ps51.ps1" 0)
assert_eq "finds OnlyPS51" "$TEST_DIR/Scripts/Smoke/OnlyPS51/run.ps51.ps1" "${SUITES_PS51[0]:-}"
assert_eq "count=1"        "1"                                             "${#SUITES_PS51[@]}"

# ── Test 3: discover_smoke_suites (empty / missing directory) ──

echo "── Test 3: discover_smoke_suites (empty) ──"

mkdir -p "$TEST_DIR/EmptySmoke"
mapfile -t SUITES_EMPTY < <(discover_smoke_suites "$TEST_DIR/EmptySmoke" "run.ps7.ps1" 0)
assert_eq "empty dir"          "0" "${#SUITES_EMPTY[@]}"

mapfile -t SUITES_NO_DIR < <(discover_smoke_suites "$TEST_DIR/NoSuchDir" "run.ps7.ps1" 0)
assert_eq "missing dir"        "0" "${#SUITES_NO_DIR[@]}"

# ── Test 4: parse_smoke_result_file ──

echo "── Test 4: parse_smoke_result_file ──"

echo "TOTAL: 5 tests, 4 pass, 1 fail, 0 skip" > "$TEST_DIR/smoke1.log"
read t p f s <<< "$(parse_smoke_result_file "$TEST_DIR/smoke1.log")"
assert_eq "tests=5"  "5" "$t"
assert_eq "pass=4"   "4" "$p"
assert_eq "fail=1"   "1" "$f"
assert_eq "skip=0"   "0" "$s"

echo "TOTAL: 10 tests, 8 pass, 0 fail, 2 skip" > "$TEST_DIR/smoke2.log"
read t p f s <<< "$(parse_smoke_result_file "$TEST_DIR/smoke2.log")"
assert_eq "tests=10" "10" "$t"
assert_eq "pass=8"   "8"  "$p"
assert_eq "fail=0"   "0"  "$f"
assert_eq "skip=2"   "2"  "$s"

echo "Some random output" > "$TEST_DIR/smoke3.log"
read t p f s <<< "$(parse_smoke_result_file "$TEST_DIR/smoke3.log")"
assert_eq "no TOTAL → zeros" "0 0 0 0" "$t $p $f $s"

: > "$TEST_DIR/smoke4.log"
read t p f s <<< "$(parse_smoke_result_file "$TEST_DIR/smoke4.log")"
assert_eq "empty file → zeros" "0 0 0 0" "$t $p $f $s"

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
