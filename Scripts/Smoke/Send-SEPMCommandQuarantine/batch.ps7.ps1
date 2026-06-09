# Smoke verification for Send-SEPMCommandQuarantine (PS7)
# Verifies the command dispatch path by sending commands to non-existent clients.
# The API returns validation errors, which confirms the dispatch was attempted.
$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"

Write-Host "=== Smoke: Send-SEPMCommandQuarantine (PS7) ==="

$results = @{}

$results.A1 = T "A1" "Quarantine to non-existent computer" `
    { Send-SEPMCommandQuarantine -ComputerName 'NonExistentPC_SmokeTest' } `
    { param($r) $r -ne $null }

$results.A2 = T "A2" "Quarantine to non-existent group" `
    { Send-SEPMCommandQuarantine -GroupName 'My Company\NonExistentSmokeGroup' } `
    { param($r) $r -ne $null }

$results.A3 = T "A3" "Unquarantine (undo=true) to non-existent computer" `
    { Send-SEPMCommandQuarantine -ComputerName 'NonExistentPC_SmokeTest' -Unquarantine } `
    { param($r) $r -ne $null }

# Summary
Write-Host "`n========== SUMMARY (PS7) ==========" -ForegroundColor Yellow
$pass = 0; $fail = 0
foreach ($k in $results.Keys | Sort-Object) {
    $v = $results[$k]
    if ($v -eq "PASS") { $pass++; Write-Host "  $k : PASS" -ForegroundColor Green }
    else { $fail++; Write-Host "  $k : FAIL" -ForegroundColor Red }
}
Write-Host "TOTAL: $($pass+$fail) tests, $pass pass, $fail fail" -ForegroundColor Yellow
