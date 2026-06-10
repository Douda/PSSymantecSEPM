$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"
. "$RepoRoot\Common-PS51.ps1"

Write-Host "=== Smoke: Start-SEPMReplication (PS5.1) ===" -ForegroundColor Yellow

$results = @{}

$results.A1 = T "A1" "Send with partner" `
    {
        try {
            Start-SEPMReplication -partnerSiteName 'RemoteSiteTest' | Out-Null
            $true
        } catch {
            $msg = $_.Exception.Message
            $msg -match 'partner|site|replication|not found'
        }
    } `
    { param($r) $r -eq $true }

$results.A2 = T "A2" "No-param call" `
    { Start-SEPMReplication | Out-Null; $true } `
    { param($r) $r -eq $true }

$pass = 0; $fail = 0; $skip = 0
foreach ($k in $results.Keys | Sort-Object) {
    $v = $results[$k]
    if ($v -eq "PASS") { $pass++; Write-Host "  $k : PASS" -ForegroundColor Green }
    elseif ($v -eq "SKIP") { $skip++; Write-Host "  $k : SKIP" -ForegroundColor Yellow }
    else { $fail++; Write-Host "  $k : FAIL" -ForegroundColor Red }
}
Write-Host "TOTAL: $($pass+$fail+$skip) tests, $pass pass, $fail fail, $skip skip" -ForegroundColor Yellow

if ($fail -gt 0) { Write-Error "Smoke tests failed: $fail failure(s)"; exit 1 }
