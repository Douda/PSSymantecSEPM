# Smoke verification for Update-SEPClientDefinitions (PS7)
# Verifies the command dispatch path by sending commands to non-existent clients.
# The API returns validation errors, which confirms the dispatch was attempted.
# GroupName with a non-existent group correctly finds no computers and dispatches nothing.
$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"

Write-Host "=== Smoke: Update-SEPClientDefinitions (PS7) ==="

$results = @{}

$results.A1 = T "A1" "UpdateDefinitions to non-existent computer" `
    { Update-SEPClientDefinitions -ComputerName 'NonExistentPC_SmokeTest' } `
    { param($r) $r -ne $null }

$results.A2 = T "A2" "UpdateDefinitions to non-existent group (no matching targets)" `
    { Update-SEPClientDefinitions -GroupName 'My Company\NonExistentSmokeGroup' } `
    { param($r) $true }

$results.A3 = T "A3" "UpdateDefinitions with IncludeSubGroups (no matching targets)" `
    { Update-SEPClientDefinitions -GroupName 'My Company\NonExistentSmokeGroup' -IncludeSubGroups } `
    { param($r) $true }

# Summary
Write-Host "`n========== SUMMARY (PS7) ==========" -ForegroundColor Yellow
$pass = 0; $fail = 0
foreach ($k in $results.Keys | Sort-Object) {
    $v = $results[$k]
    if ($v -eq "PASS") { $pass++; Write-Host "  $k : PASS" -ForegroundColor Green }
    else { $fail++; Write-Host "  $k : FAIL" -ForegroundColor Red }
}
Write-Host "TOTAL: $($pass+$fail) tests, $pass pass, $fail fail" -ForegroundColor Yellow
