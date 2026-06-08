#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────────────
# Scripts/bootstrap-smoke.sh — Master smoke test bootstrap
# ────────────────────────────────────────────────────────────────────────────
#
# Idempotent orchestrator. Run from the repo root.
#
# Prerequisites (run ONCE manually on a fresh VM):
#   1. Windows VM with SEPM installed + admin logged in at least once
#   2. Run setup-vm.ps1 on the VM as Administrator → enables WinRM
#
# After those one-time steps, this script handles everything:
#   • Module build (ModuleBuilder)
#   • SEPM config + credentials on devcontainer AND on VM
#   • Module deployment to VM (shared volume)
#   • Smoke tests: PS 7 (devcontainer) + PS 5.1 (WinRM)
#   • Summary report
#
# Env vars (all optional — defaults work for local dev):
#   VM_USER                  — Windows username on VM (default: smokeuser)
#   WINRM_USER, WINRM_PASS   — Windows VM credentials (default: same as VM_USER)
#   SEPM_USER, SEPM_PASS     — SEPM admin credentials
#   SHARED_VOLUME            — host-side path mapped to VM Desktop/Shared
#   SKIP_PS51                — set to 1 to skip WinRM smoke tests
#   SKIP_PS7                 — set to 1 to skip PS7 smoke tests
#   SEED                     — set to 1 to seed SEPM data before smoke tests (default: 0)
#
# Usage:
#   ./Scripts/bootstrap-smoke.sh
#   SKIP_PS51=1 ./Scripts/bootstrap-smoke.sh          # PS7 only
#   SKIP_PS7=1 ./Scripts/bootstrap-smoke.sh           # PS5.1 only
# ────────────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Defaults (from docs/agents/smoke-testing.md) ──
export VM_USER="${VM_USER:-smokeuser}"
export WINRM_USER="${WINRM_USER:-$VM_USER}"
export WINRM_PASS="${WINRM_PASS:-smokepassword}"
export WINRM_HOST="${WINRM_HOST:-localhost}"
export WINRM_PORT="${WINRM_PORT:-5986}"
export SEPM_USER="${SEPM_USER:-admin}"
export SEPM_PASS="${SEPM_PASS:-MyComplexPassword1!}"
export SEPM_HOST="${SEPM_HOST:-localhost}"
export SEPM_PORT="${SEPM_PORT:-8446}"
SEPM_API="https://${SEPM_HOST}:${SEPM_PORT}/sepm/api/v1/version"
CONTAINER="${CONTAINER:-omarchy-windows}"
SHARED_VOLUME="${SHARED_VOLUME:-$HOME/Windows}"
VM_DESKTOP="C:\\Users\\${VM_USER}\\Desktop\\Shared"
VM_MODULE_DIR="${VM_DESKTOP}\\PSSymantecSEPM"

# ── Color helpers ──
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
pass=0; fail=0; skipped=0

section()  { echo -e "\n${CYAN}══════ ${1} ══════${NC}"; }
ok()       { echo -e "  ${GREEN}✓${NC} $1"; }
warn()     { echo -e "  ${YELLOW}⚠${NC} $1"; }
err()      { echo -e "  ${RED}✗${NC} $1"; ((fail++)) || true; }
info()     { echo -e "  ${BOLD}→${NC} $1"; }

die() {
    echo -e "\n${RED}FATAL: $1${NC}"
    echo "Fix the issue above and re-run."
    exit 1
}

# ────────────────────────────────────────────────────────────────────────────
# Phase 1: Prerequisites
# ────────────────────────────────────────────────────────────────────────────
section "Phase 1: Prerequisites"

# 1a. Tools
for tool in docker pwsh python3 curl; do
    if command -v "$tool" &>/dev/null; then
        ok "$tool found ($(command -v $tool))"
    else
        die "$tool not found in PATH"
    fi
done

# 1b. ModuleBuilder (check inside pwsh)
if pwsh -NoProfile -c "(Get-Module ModuleBuilder -ListAvailable).Name" 2>/dev/null | grep -q ModuleBuilder; then
    ok "ModuleBuilder available"
else
    die "ModuleBuilder not installed. Run: pwsh -c 'Install-Module ModuleBuilder -Force'"
fi

# 1c. Container running
if docker ps --filter "name=${CONTAINER}" --format '{{.Names}}' | grep -q "${CONTAINER}"; then
    ok "Container '${CONTAINER}' running"
else
    warn "Container '${CONTAINER}' not running — starting..."
    docker start "${CONTAINER}" || die "Failed to start container"
    ok "Container started"
fi

# 1d. SEPM API reachable (retry up to 2 min for VM boot)
info "Waiting for SEPM API..."
for i in $(seq 1 24); do
    if curl -sk "${SEPM_API}" &>/dev/null; then
        ok "SEPM API reachable at ${SEPM_HOST}:${SEPM_PORT}"
        break
    fi
    if [ "$i" -eq 24 ]; then
        die "SEPM API not reachable after 2 min. Is SEPM running in the VM?"
    fi
    sleep 5
done

# ────────────────────────────────────────────────────────────────────────────
# Phase 2: Build module
# ────────────────────────────────────────────────────────────────────────────
section "Phase 2: Build module"

cd "${REPO_ROOT}"
info "Building module with ModuleBuilder..."
pwsh -NoProfile -c "
    Import-Module ModuleBuilder -Force
    Build-Module -SourcePath ./Source/PSSymantecSEPM.psd1 -SemVer 0.0.1
" || die "Module build failed"

if [ -f "${REPO_ROOT}/Output/PSSymantecSEPM/PSSymantecSEPM.psm1" ]; then
    ok "Module built → Output/PSSymantecSEPM/"
else
    die "Built module .psm1 not found"
fi

# ────────────────────────────────────────────────────────────────────────────
# Phase 3: Devcontainer SEPM config + credentials (idempotent)
# ────────────────────────────────────────────────────────────────────────────
section "Phase 3: Devcontainer SEPM setup"

CONFIG_DIR="${HOME}/.config/PSSymantecSEPM"
CONFIG_FILE="${CONFIG_DIR}/config.json"
CREDS_FILE="${CONFIG_DIR}/creds.xml"
TOKEN_FILE="${HOME}/.local/share/PSSymantecSEPM/accessToken.xml"

mkdir -p "${CONFIG_DIR}" "$(dirname "${TOKEN_FILE}")"

# Config
echo "{\"port\":${SEPM_PORT},\"ServerAddress\":\"${SEPM_HOST}\"}" > "${CONFIG_FILE}"
ok "config.json written"

# Credentials (Export-Clixml via pwsh)
rm -f "${CREDS_FILE}" "${TOKEN_FILE}"
pwsh -NoProfile -c "
    \$sec = ConvertTo-SecureString '${SEPM_PASS}' -AsPlainText -Force
    \$cred = New-Object System.Management.Automation.PSCredential('${SEPM_USER}', \$sec)
    \$cred | Export-Clixml -Path '${CREDS_FILE}' -Force
" || die "Failed to create creds.xml"
ok "creds.xml written"

# Verify module loads and authenticates
info "Verifying module auth..."
pwsh -NoProfile -c "
    Import-Module '${REPO_ROOT}/Output/PSSymantecSEPM/PSSymantecSEPM.psm1' -Force
    \$mod = Get-Module PSSymantecSEPM
    & \$mod { \$script:SkipCert = \$true }
    try {
        \$v = Get-SEPMVersion
        Write-Host \"  ✓ SEPM version: \$(\$v.version)\"
    } catch {
        Write-Error \"Auth failed: \$_\"
        exit 1
    }
" || die "Module auth verification failed"
ok "Module authenticates successfully"

# ────────────────────────────────────────────────────────────────────────────
# Phase 4: VM WinRM + SEPM setup (idempotent)
# ────────────────────────────────────────────────────────────────────────────
section "Phase 4: VM setup"

# 4a. Deploy init-sepm-vm.ps1 to shared volume
INIT_VM_SRC="${REPO_ROOT}/Scripts/init-sepm-vm.ps1"
INIT_VM_DST="${SHARED_VOLUME}/init-sepm-vm.ps1"

if [ ! -f "${INIT_VM_SRC}" ]; then
    die "init-sepm-vm.ps1 not found at ${INIT_VM_SRC}"
fi
cp "${INIT_VM_SRC}" "${INIT_VM_DST}"
ok "init-sepm-vm.ps1 → shared volume"

# 4b. Write WinRM connectivity check to shared volume
printf '\xef\xbb\xbfWrite-Host "WinRM OK"' > "${SHARED_VOLUME}/_bootstrap_winrm_check.ps1"

info "Checking WinRM connectivity..."
WINRM_OUT=$(python3 "${REPO_ROOT}/Scripts/invoke-winrm.py" "${VM_DESKTOP}\\_bootstrap_winrm_check.ps1" 2>&1) || {
    err "WinRM not reachable"
    echo ""
    echo "  Run setup-vm.ps1 on the VM once (as Administrator):"
    echo "    Copy Scripts/setup-vm.ps1 → ${VM_DESKTOP}\\setup-vm.ps1"
    echo "    Run: ${VM_DESKTOP}\\setup-vm.ps1"
    echo ""
    die "WinRM not configured on VM"
}
rm -f "${SHARED_VOLUME}/_bootstrap_winrm_check.ps1"
if echo "${WINRM_OUT}" | grep -q "WinRM OK"; then
    ok "WinRM reachable"
else
    err "WinRM unexpected output: ${WINRM_OUT}"
    die "WinRM check failed"
fi

# 4c. Run init-sepm-vm.ps1 on VM
info "Running init-sepm-vm.ps1 on VM..."
python3 "${REPO_ROOT}/Scripts/invoke-winrm.py" "${VM_DESKTOP}\\init-sepm-vm.ps1" 2>&1 || {
    err "init-sepm-vm.ps1 failed on VM"
    die "VM SEPM setup failed"
}
ok "VM SEPM config + credentials set up"

# ────────────────────────────────────────────────────────────────────────────
# Phase 5: Deploy module to VM
# ────────────────────────────────────────────────────────────────────────────
section "Phase 5: Deploy module to VM"

info "Copying module to shared volume..."
rm -rf "${SHARED_VOLUME}/PSSymantecSEPM"
cp -r "${REPO_ROOT}/Output/PSSymantecSEPM" "${SHARED_VOLUME}/PSSymantecSEPM"
ok "Module deployed → ${VM_MODULE_DIR}"

# 5b. Verify module on VM (after deployment)
info "Verifying module auth on VM..."
printf '\xef\xbb\xbf%s' "Import-Module '${VM_MODULE_DIR}\\PSSymantecSEPM.psm1' -Force; \$m=Get-Module PSSymantecSEPM; & \$m {\$script:SkipCert=\$true}; Get-SEPMVersion | Select -Expand version" > "${SHARED_VOLUME}/_bootstrap_vm_verify.ps1"
VM_VERIFY_OUT=$(python3 "${REPO_ROOT}/Scripts/invoke-winrm.py" "${VM_DESKTOP}\\_bootstrap_vm_verify.ps1" 2>&1) || {
    err "VM module auth failed"
    die "VM module verification failed"
}
rm -f "${SHARED_VOLUME}/_bootstrap_vm_verify.ps1"
if echo "${VM_VERIFY_OUT}" | grep -q "14\."; then
    ok "VM module authenticates (version: $(echo "${VM_VERIFY_OUT}" | grep -oP '14\.\S+' | head -1))"
else
    warn "VM verify output did not contain version string"
fi

# ────────────────────────────────────────────────────────────────────────────
# Phase 5.5: Seed data (optional)
# ────────────────────────────────────────────────────────────────────────────
section "Phase 5.5: Seed data"

if [ "${SEED:-0}" = "0" ]; then
    info "SEED=0 — skipping seed data"
else
    # 5.5a. Devcontainer (PS7)
    SEED_SCRIPT="${REPO_ROOT}/Scripts/Seed-SEPMData.ps1"
    if [ ! -f "${SEED_SCRIPT}" ]; then
        warn "Seed-SEPMData.ps1 not found at ${SEED_SCRIPT} — skipping"
    else
        info "Seeding SEPM data on devcontainer (PS7)..."
        if pwsh -NoProfile -File "${SEED_SCRIPT}" 2>&1; then
            ok "Seed data created (PS7)"
        else
            warn "Seed data (PS7) reported errors — continuing"
        fi
    fi

    # 5.5b. VM (PS5.1)
    SEED_FILES=("${REPO_ROOT}"/Scripts/Seed-*.ps1)
    if [ ${#SEED_FILES[@]} -eq 0 ] || [ ! -f "${SEED_FILES[0]}" ]; then
        warn "No Seed-*.ps1 files found — skipping VM seed"
    else
        info "Deploying seed scripts to VM..."
        cp "${REPO_ROOT}"/Scripts/Seed-*.ps1 "${SHARED_VOLUME}/"
        ok "Seed scripts → shared volume"

        info "Seeding SEPM data on VM (PS5.1)..."
        VM_SEED_SCRIPT="${VM_DESKTOP}\\Seed-SEPMData.ps1"
        if python3 "${REPO_ROOT}/Scripts/invoke-winrm.py" "${VM_SEED_SCRIPT}" 2>&1; then
            ok "Seed data created (PS5.1)"
        else
            warn "Seed data (PS5.1) reported errors — continuing"
        fi
    fi
fi

# ────────────────────────────────────────────────────────────────────────────
# Phase 6: Smoke tests — PS 7 (devcontainer)
# ────────────────────────────────────────────────────────────────────────────
section "Phase 6: Smoke tests — PS 7"

BATCH_PS7="${REPO_ROOT}/Scripts/Smoke/Update-SEPMExceptionPolicy/batch.ps7.ps1"

if [ "${SKIP_PS7:-0}" = "1" ]; then
    warn "SKIP_PS7=1 — skipping PS7 smoke tests"
    ((skipped++)) || true
elif [ -f "${BATCH_PS7}" ]; then
    info "Running batch.ps7.ps1..."
    PS7_OUT=$(pwsh -NoProfile -File "${BATCH_PS7}" 2>&1) || true
    echo "${PS7_OUT}"

    # Parse summary
    PS7_PASS=$(echo "${PS7_OUT}" | grep -oP '\d+(?= pass)' | head -1 || echo "0")
    PS7_FAIL=$(echo "${PS7_OUT}" | grep -oP '\d+(?= fail)' | head -1 || echo "0")
    PS7_TOTAL=$(echo "${PS7_OUT}" | grep -oP '\d+(?= tests)' | head -1 || echo "0")
    pass=$((pass + PS7_PASS))
    fail=$((fail + PS7_FAIL))

    if [ "${PS7_FAIL}" -gt 0 ]; then
        warn "PS7: ${PS7_PASS}/${PS7_TOTAL} pass, ${PS7_FAIL} failures"
    else
        ok "PS7: ${PS7_PASS}/${PS7_TOTAL} all pass"
    fi
else
    err "batch.ps7.ps1 not found at ${BATCH_PS7}"
fi

# ────────────────────────────────────────────────────────────────────────────
# Phase 7: Smoke tests — PS 5.1 (WinRM)
# ────────────────────────────────────────────────────────────────────────────
section "Phase 7: Smoke tests — PS 5.1"

BATCH_PS51="${REPO_ROOT}/Scripts/Smoke/Update-SEPMExceptionPolicy/batch.ps51.ps1"
BATCH_PS51_VM="${VM_DESKTOP}\\batch.ps51.ps1"

if [ "${SKIP_PS51:-0}" = "1" ]; then
    warn "SKIP_PS51=1 — skipping PS5.1 smoke tests"
    ((skipped++)) || true
elif [ -f "${BATCH_PS51}" ]; then
    # Deploy batch script to VM
    cp "${BATCH_PS51}" "${SHARED_VOLUME}/batch.ps51.ps1"
    ok "batch.ps51.ps1 → shared volume"

    info "Running batch.ps51.ps1 via WinRM (this may take a few minutes)..."
    PS51_OUT=$(python3 "${REPO_ROOT}/Scripts/invoke-winrm.py" "${BATCH_PS51_VM}" 2>&1) || true
    echo "${PS51_OUT}"

    # Parse summary
    PS51_PASS=$(echo "${PS51_OUT}" | grep -oP '\d+(?= pass)' | head -1 || echo "0")
    PS51_FAIL=$(echo "${PS51_OUT}" | grep -oP '\d+(?= fail)' | head -1 || echo "0")
    PS51_TOTAL=$(echo "${PS51_OUT}" | grep -oP '\d+(?= tests)' | head -1 || echo "0")
    pass=$((pass + PS51_PASS))
    fail=$((fail + PS51_FAIL))

    if [ "${PS51_FAIL}" -gt 0 ]; then
        warn "PS5.1: ${PS51_PASS}/${PS51_TOTAL} pass, ${PS51_FAIL} failures"
    else
        ok "PS5.1: ${PS51_PASS}/${PS51_TOTAL} all pass"
    fi
else
    err "batch.ps51.ps1 not found at ${BATCH_PS51}"
fi

# ────────────────────────────────────────────────────────────────────────────
# Summary
# ────────────────────────────────────────────────────────────────────────────
section "Summary"

total=$((pass + fail))
echo -e "  Total:  ${BOLD}${total}${NC} tests"
echo -e "  Pass:   ${GREEN}${pass}${NC}"
echo -e "  Fail:   ${RED}${fail}${NC}"

if [ "${skipped}" -gt 0 ]; then
    echo -e "  Skip:   ${YELLOW}${skipped}${NC} platform(s)"
fi
echo ""

if [ "${fail}" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}══ All tests passed ══${NC}"
    exit 0
else
    echo -e "${RED}${BOLD}══ ${fail} test(s) failed ══${NC}"
    exit 1
fi
