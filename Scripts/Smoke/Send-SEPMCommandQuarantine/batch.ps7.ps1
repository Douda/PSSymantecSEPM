# Smoke verification for Send-SEPMCommandQuarantine (PS7)
# Verifies the command dispatch path by sending commands to non-existent clients.
# The API returns validation errors, which confirms the dispatch was attempted.
$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"

Write-Host "=== Smoke: Send-SEPMCommandQuarantine (PS7) ==="

$results = @{}

# A1: ComputerName path
Write-Host "--- A1 : Quarantine to non-existent computer ---" -ForegroundColor Cyan
try {
    $r = Send-SEPMCommandQuarantine -ComputerName 'NonExistentPC_SmokeTest'
    if ($r -ne $null) { Write-Host "  VERDICT: PASS (API responded - dispatch attempted)" -ForegroundColor Green; $results.A1 = "PASS" }
    else { Write-Host "  VERDICT: FAIL (no response)" -ForegroundColor Red; $results.A1 = "FAIL" }
} catch { Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red; $results.A1 = "FAIL" }

# A2: GroupName path
Write-Host "--- A2 : Quarantine to non-existent group ---" -ForegroundColor Cyan
try {
    $r = Send-SEPMCommandQuarantine -GroupName 'My Company\NonExistentSmokeGroup'
    if ($r -ne $null) { Write-Host "  VERDICT: PASS (API responded - dispatch attempted)" -ForegroundColor Green; $results.A2 = "PASS" }
    else { Write-Host "  VERDICT: FAIL (no response)" -ForegroundColor Red; $results.A2 = "FAIL" }
} catch { Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red; $results.A2 = "FAIL" }

# A3: Unquarantine (undo=true)
Write-Host "--- A3 : Unquarantine (undo=true) to non-existent computer ---" -ForegroundColor Cyan
try {
    $r = Send-SEPMCommandQuarantine -ComputerName 'NonExistentPC_SmokeTest' -Unquarantine
    if ($r -ne $null) { Write-Host "  VERDICT: PASS (API responded - dispatch attempted)" -ForegroundColor Green; $results.A3 = "PASS" }
    else { Write-Host "  VERDICT: FAIL (no response)" -ForegroundColor Red; $results.A3 = "FAIL" }
} catch { Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red; $results.A3 = "FAIL" }

# Summary
Write-Host "`n========== SUMMARY (PS7) ==========" -ForegroundColor Yellow
$pass = 0; $fail = 0
foreach ($k in $results.Keys | Sort-Object) {
    $v = $results[$k]
    if ($v -eq "PASS") { $pass++; Write-Host "  $k : PASS" -ForegroundColor Green }
    else { $fail++; Write-Host "  $k : FAIL" -ForegroundColor Red }
}
Write-Host "TOTAL: $($pass+$fail) tests, $pass pass, $fail fail" -ForegroundColor Yellow
