#!/usr/bin/env bash
# verify-tools.sh — Verify quality tools are installed in sandcastle image.
#
# Run inside the sandcastle container after build:
#   docker run --rm sandcastle-image:latest bash /home/agent/verify-tools.sh
#
# Exit 0 = all tools present at correct versions.
# Exit 1 = one or more checks failed.

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASSED=0
FAILED=0

check_cmd() {
    local name="$1"
    local cmd="$2"
    local expected="$3"

    printf "Check %-20s " "$name:"
    local actual
    if actual=$($cmd 2>&1); then
        if [ -n "$expected" ]; then
            if echo "$actual" | grep -qF "$expected"; then
                printf "${GREEN}PASS${NC}  (%s)\n" "$expected"
                PASSED=$((PASSED + 1))
            else
                printf "${RED}FAIL${NC}  wanted '%s', got '%s'\n" "$expected" "$actual"
                FAILED=$((FAILED + 1))
            fi
        else
            printf "${GREEN}PASS${NC}\n"
            PASSED=$((PASSED + 1))
        fi
    else
        printf "${RED}FAIL${NC}  (command error: %s)\n" "$actual"
        FAILED=$((FAILED + 1))
    fi
}

echo "=== Sandcastle Tool Verification ==="
echo ""

# 1. pwsh on PATH
check_cmd "pwsh" "pwsh --version" ""

# 2. Pester module importable
check_cmd "Pester" "pwsh -NoProfile -Command 'Import-Module Pester -ErrorAction Stop; (Get-Module Pester).Version'" "5."

# 3. ModuleBuilder importable
check_cmd "ModuleBuilder" "pwsh -NoProfile -Command 'Import-Module ModuleBuilder -ErrorAction Stop; (Get-Module ModuleBuilder).Version'" ""

# 4. PSScriptAnalyzer importable
check_cmd "PSScriptAnalyzer" "pwsh -NoProfile -Command 'Import-Module PSScriptAnalyzer -ErrorAction Stop; (Get-Module PSScriptAnalyzer).Version'" ""

# 5. gh on PATH
check_cmd "gh" "gh --version" ""

# 6. pi on PATH
check_cmd "pi" "pi --version" ""

# 7. ripgrep on PATH
check_cmd "ripgrep" "which rg" ""

# 8. Build-ModuleLocal defined in pwsh profile
check_cmd "Build-ModuleLocal" "pwsh -NoProfile -Command 'Get-Command Build-ModuleLocal -ErrorAction Stop | Select-Object -ExpandProperty Name'" "Build-ModuleLocal"

# 9. Node.js (needed for pi + main.mts runner)
check_cmd "node" "node --version" ""

echo ""
echo "=== Results: ${GREEN}$PASSED passed${NC}, ${RED}$FAILED failed${NC} ==="

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
exit 0
