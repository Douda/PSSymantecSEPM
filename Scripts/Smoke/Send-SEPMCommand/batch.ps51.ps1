$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"
. "$RepoRoot\Common-PS51.ps1"

Write-Host "=== Smoke: Send-SEPMCommand (PS5.1) ===" -ForegroundColor Yellow

$results = @{}

$results.A1 = T "A1" "ActiveScan with real computer" `
    { Send-SEPMCommand -Type ActiveScan -ComputerName 'WIN-P093KPK2K7Q' } `
    { param($r) $r -ne $null }

$results.A2 = T "A2" "ActiveScan with non-existent computer" `
    { Send-SEPMCommand -Type ActiveScan -ComputerName 'NonExistentComputer12345' } `
    { param($r) $r -ne $null }

$results.A3 = T "A3" "ActiveScan via pipeline" `
    { 'WIN-P093KPK2K7Q' | Send-SEPMCommand -Type ActiveScan } `
    { param($r) $r -ne $null }

$results.F1 = T "F1" "FullScan with real computer" `
    { Send-SEPMCommand -Type FullScan -ComputerName 'WIN-P093KPK2K7Q' } `
    { param($r) $r -ne $null }

$results.F2 = T "F2" "FullScan with non-existent computer" `
    { Send-SEPMCommand -Type FullScan -ComputerName 'NonExistentComputer12345' } `
    { param($r) $r -ne $null }

$results.Q1 = T "Q1" "Quarantine with real computer" `
    { Send-SEPMCommand -Type Quarantine -ComputerName 'WIN-P093KPK2K7Q' } `
    { param($r) $r -ne $null }

$results.Q2 = T "Q2" "Quarantine with -Undo" `
    { Send-SEPMCommand -Type Quarantine -ComputerName 'WIN-P093KPK2K7Q' -Undo } `
    { param($r) $r -ne $null }

$results.U1 = T "U1" "UpdateContent with real computer" `
    { Send-SEPMCommand -Type UpdateContent -ComputerName 'WIN-P093KPK2K7Q' } `
    { param($r) $r -ne $null }

$results.U2 = T "U2" "UpdateContent with non-existent computer" `
    { Send-SEPMCommand -Type UpdateContent -ComputerName 'NonExistentComputer12345' } `
    { param($r) $r -ne $null }

# === Summary ===
Write-Host "`n========== SUMMARY (PS5.1) ==========" -ForegroundColor Yellow
$pass = 0; $fail = 0; $skip = 0
foreach ($k in $results.Keys | Sort-Object) {
    $v = $results[$k]
    if ($v -eq "PASS") { $pass++; Write-Host "  $k : PASS" -ForegroundColor Green }
    elseif ($v -eq "SKIP") { $skip++; Write-Host "  $k : SKIP" -ForegroundColor Yellow }
    else { $fail++; Write-Host "  $k : FAIL" -ForegroundColor Red }
}
Write-Host "TOTAL: $($pass+$fail+$skip) tests, $pass pass, $fail fail, $skip skip" -ForegroundColor Yellow

if ($fail -gt 0) { exit 1 }
