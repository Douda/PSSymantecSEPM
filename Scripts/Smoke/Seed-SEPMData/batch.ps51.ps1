# Smoke verification for Seed-SEPMData orchestrator (PS5.1)
# Deploy to shared volume, then run via:
#   python3 Scripts/invoke-winrm.py 'C:\Users\smokeuser\Desktop\Shared\smoke-seed.batch.ps1'

$ErrorActionPreference = "Continue"

$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"
. "$RepoRoot\Common-PS51.ps1"

Write-Host "=== Smoke: Seed-SEPMData (PS5.1) ==="

$seedScript = "$RepoRoot\Seed-SEPMData.ps1"

# ── Test: -Categories Test ──
Write-Host "--- Test: -Categories Test ---"
$result = & $seedScript -Categories Test

if (-not $result) { throw "FAIL: no output from -Categories Test" }
if (($result -match 'Framework ready').Count -eq 0) { throw "FAIL: expected 'Framework ready', got: $result" }
if (($result -match 'Force: False').Count -eq 0) { throw "FAIL: expected 'Force: False', got: $result" }
Write-Host "  VERDICT: PASS"

# ── Test: -Categories Test -Force ──
Write-Host "--- Test: -Categories Test -Force ---"
$result = & $seedScript -Categories Test -Force

if (-not $result) { throw "FAIL: no output from -Categories Test -Force" }
if (($result -match 'Framework ready').Count -eq 0) { throw "FAIL: expected 'Framework ready', got: $result" }
if (($result -match 'Force: True').Count -eq 0) { throw "FAIL: expected 'Force: True', got: $result" }
Write-Host "  VERDICT: PASS"

# ── Test: No parameters (defaults to all) ──
Write-Host "--- Test: No parameters ---"
$result = & $seedScript

if (-not $result) { throw "FAIL: no output from no-params" }
if (($result -match 'No categories implemented yet').Count -eq 0) { throw "FAIL: expected 'No categories implemented yet', got: $result" }
Write-Host "  VERDICT: PASS"

Write-Host "`n=== Smoke: Seed-SEPMData (PS5.1) — ALL PASS ==="
