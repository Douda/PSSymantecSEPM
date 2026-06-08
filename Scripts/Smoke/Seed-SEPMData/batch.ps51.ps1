# Smoke verification for Seed-SEPMData orchestrator (PS5.1)
# Deploy to shared volume, then run via:
#   python3 Scripts/invoke-winrm.py 'C:\Users\smokeuser\Desktop\Shared\smoke-seed.batch.ps1'

$ErrorActionPreference = "Continue"

$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"
. "$RepoRoot\Common-PS51.ps1"

Write-Host "=== Smoke: Seed-SEPMData (PS5.1) ==="

# Copy seed scripts to shared volume root (deployed there from host)
# Seed-Groups.ps1 and Seed-SEPMData.ps1 are already in $RepoRoot
# (they were deployed directly, not in a Scripts/ subdirectory)

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

# ── Test: -Categories Groups (live seed) ──
Write-Host "--- Test: -Categories Groups ---"
$beforeCount = (Get-SEPMGroups).Count
$result = & $seedScript -Categories Groups
$afterCount = (Get-SEPMGroups).Count

if (-not $result) { throw "FAIL: no output from -Categories Groups" }
if (($result -match 'Groups seeded:').Count -eq 0) { throw "FAIL: expected seed count, got: $result" }
# Groups may already exist from other smoke runs; just verify nothing was lost
if ($afterCount -lt $beforeCount) { throw "FAIL: group count decreased ($beforeCount -> $afterCount)" }
Write-Host "  VERDICT: PASS (groups: $afterCount, seeded count reported)"

# ── Test: Groups Idempotency ──
Write-Host "--- Test: Groups Idempotency ---"
$beforeCount = (Get-SEPMGroups).Count
$result = & $seedScript -Categories Groups
$afterCount = (Get-SEPMGroups).Count
if ($afterCount -ne $beforeCount) { throw "FAIL: counts changed on re-run ($beforeCount -> $afterCount)" }
Write-Host "  VERDICT: PASS (idempotent, $afterCount groups)"

Write-Host "`n=== Smoke: Seed-SEPMData (PS5.1) — ALL PASS ==="
