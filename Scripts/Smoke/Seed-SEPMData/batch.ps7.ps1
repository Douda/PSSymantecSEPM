# Smoke verification for Seed-SEPMData orchestrator (PS7)
# Usage: pwsh -NoProfile -File Scripts/Smoke/Seed-SEPMData/batch.ps7.ps1

$ErrorActionPreference = "Continue"

$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"

Write-Host "=== Smoke: Seed-SEPMData (PS7) ==="

$seedScript = Join-Path -Path $RepoRoot -ChildPath 'Scripts/Seed-SEPMData.ps1'

# ── Test: -Categories Test ──
Write-Host "--- Test: -Categories Test ---"
$result = & $seedScript -Categories Test

if (-not $result) { throw "FAIL: no output from -Categories Test" }
if (($result -match 'Framework ready').Count -eq 0) { throw "FAIL: expected 'Framework ready', got: $result" }
if (($result -match 'Force: False').Count -eq 0) { throw "FAIL: expected 'Force: False', got: $result" }
Write-Host "  VERDICT: PASS" -ForegroundColor Green

# ── Test: -Categories Test -Force ──
Write-Host "--- Test: -Categories Test -Force ---"
$result = & $seedScript -Categories Test -Force

if (-not $result) { throw "FAIL: no output from -Categories Test -Force" }
if (($result -match 'Framework ready').Count -eq 0) { throw "FAIL: expected 'Framework ready', got: $result" }
if (($result -match 'Force: True').Count -eq 0) { throw "FAIL: expected 'Force: True', got: $result" }
Write-Host "  VERDICT: PASS" -ForegroundColor Green

# ── Test: No parameters (defaults to all) ──
Write-Host "--- Test: No parameters ---"
$result = & $seedScript

if (-not $result) { throw "FAIL: no output from no-params" }
if (($result -match 'No categories implemented yet').Count -eq 0) { throw "FAIL: expected 'No categories implemented yet', got: $result" }
Write-Host "  VERDICT: PASS" -ForegroundColor Green

# ── Test: -Categories Groups (live seed) ──
Write-Host "--- Test: -Categories Groups ---"
$beforeCount = (Get-SEPMGroups).Count
$result = & $seedScript -Categories Groups
$afterCount = (Get-SEPMGroups).Count

if (-not $result) { throw "FAIL: no output from -Categories Groups" }
if (($result -match 'Groups seeded:').Count -eq 0) { throw "FAIL: expected seed count, got: $result" }
if ($afterCount -le $beforeCount) { throw "FAIL: group count did not increase ($beforeCount -> $afterCount)" }
$added = $afterCount - $beforeCount
Write-Host "  VERDICT: PASS (groups: $beforeCount -> $afterCount, +$added)" -ForegroundColor Green

# ── Test: Groups Idempotency ──
Write-Host "--- Test: Groups Idempotency ---"
$beforeCount = (Get-SEPMGroups).Count
$result = & $seedScript -Categories Groups
$afterCount = (Get-SEPMGroups).Count
if ($afterCount -ne $beforeCount) { throw "FAIL: counts changed on re-run ($beforeCount -> $afterCount)" }
Write-Host "  VERDICT: PASS (idempotent, $afterCount groups)" -ForegroundColor Green

# ── Test: -Categories Admins (live seed) ──
Write-Host "--- Test: -Categories Admins ---"
$beforeCount = (Get-SEPMAdmins).Count
$result = & $seedScript -Categories Admins
$afterCount = (Get-SEPMAdmins).Count

if (-not $result) { throw "FAIL: no output from -Categories Admins" }
if (($result -match 'Admins seeded:').Count -eq 0) { throw "FAIL: expected seed count, got: $result" }
if ($afterCount -le $beforeCount) { throw "FAIL: admin count did not increase ($beforeCount -> $afterCount)" }
$added = $afterCount - $beforeCount
Write-Host "  VERDICT: PASS (admins: $beforeCount -> $afterCount, +$added)" -ForegroundColor Green

# ── Test: Admins Idempotency ──
Write-Host "--- Test: Admins Idempotency ---"
$beforeCount = (Get-SEPMAdmins).Count
$result = & $seedScript -Categories Admins
$afterCount = (Get-SEPMAdmins).Count
if ($afterCount -ne $beforeCount) { throw "FAIL: counts changed on re-run ($beforeCount -> $afterCount)" }
Write-Host "  VERDICT: PASS (idempotent, $afterCount admins)" -ForegroundColor Green

Write-Host "`n=== Smoke: Seed-SEPMData (PS7) — ALL PASS ===" -ForegroundColor Green
