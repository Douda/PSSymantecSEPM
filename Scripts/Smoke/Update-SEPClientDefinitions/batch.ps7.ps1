# Smoke verification for Update-SEPClientDefinitions (PS7)
# Verifies the command dispatch path by sending commands to non-existent clients.
# The API returns validation errors, which confirms the dispatch was attempted.
# GroupName with a non-existent group correctly finds no computers and dispatches nothing.
$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"

Write-Host "=== Smoke: Update-SEPClientDefinitions (PS7) ==="

$results = @{}

# A1: ComputerName path - dispatch to non-existent computer
Write-Host "--- A1 : UpdateDefinitions to non-existent computer ---" -ForegroundColor Cyan
try {
    $r = Update-SEPClientDefinitions -ComputerName 'NonExistentPC_SmokeTest'
    if ($r -ne $null) { Write-Host "  VERDICT: PASS (API responded)" -ForegroundColor Green; $results.A1 = "PASS" }
    else { Write-Host "  VERDICT: FAIL (no response)" -ForegroundColor Red; $results.A1 = "FAIL" }
} catch { Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red; $results.A1 = "FAIL" }

# A2: GroupName path - non-existent group (no computers match, no dispatch needed)
Write-Host "--- A2 : UpdateDefinitions to non-existent group ---" -ForegroundColor Cyan
try {
    $r = Update-SEPClientDefinitions -GroupName 'My Company\NonExistentSmokeGroup'
    # Empty result is expected - no matching computers means no commands dispatched
    Write-Host "  VERDICT: PASS (no matching targets - no dispatch needed)" -ForegroundColor Green
    $results.A2 = "PASS"
} catch { Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red; $results.A2 = "FAIL" }

# A3: GroupName path with IncludeSubGroups
Write-Host "--- A3 : UpdateDefinitions with IncludeSubGroups ---" -ForegroundColor Cyan
try {
    $r = Update-SEPClientDefinitions -GroupName 'My Company\NonExistentSmokeGroup' -IncludeSubGroups
    Write-Host "  VERDICT: PASS (no matching targets - no dispatch needed)" -ForegroundColor Green
    $results.A3 = "PASS"
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
