# Smoke verification for Send-SEPMCommandClearIronCache (PS7)
# Verifies the command dispatch path by sending commands to non-existent clients.
# The API returns validation errors, which confirms the dispatch was attempted.
$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"

Write-Host "=== Smoke: Send-SEPMCommandClearIronCache (PS7) ==="

$sha256Hash = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
$md5Hash = 'd41d8cd98f00b204e9800998ecf8427e'

$results = @{}

$results.A1 = T "A1" "ClearIronCache SHA256 to non-existent computer" `
    { Send-SEPMCommandClearIronCache -ComputerName 'NonExistentPC_SmokeTest' -SHA256 $sha256Hash } `
    { param($r) $r -ne $null }

$results.A2 = T "A2" "ClearIronCache to non-existent group" `
    { Send-SEPMCommandClearIronCache -GroupName 'My Company\NonExistentSmokeGroup' } `
    { param($r) $r -ne $null }

$results.A3 = T "A3" "ClearIronCache MD5 to non-existent computer" `
    { Send-SEPMCommandClearIronCache -ComputerName 'NonExistentPC_SmokeTest' -MD5 $md5Hash } `
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
