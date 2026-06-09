# Smoke: Start-SEPScan (PS7)
# Usage: pwsh -NoProfile -File Scripts/Smoke/Start-SEPScan/batch.ps7.ps1

$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"

Write-Host "=== Smoke: Start-SEPScan (PS7) ===" -ForegroundColor Yellow

$results = @{}

# ── Discovery: find a computer ──
$computers = @(Get-SEPComputers -ComputerName 'WIN-P093KPK2K7Q' -ErrorAction SilentlyContinue)
if ($computers.Count -eq 0) {
    $results.A1 = Skip "A1" "ActiveScan" "No computers found"
    $results.A2 = Skip "A2" "FullScan" "No computers found"
    $results.A3 = Skip "A3" "Pipeline input" "No computers found"
    $results.A4 = Skip "A4" "Invalid computer" "No computers for context"
    $results.A5 = Skip "A5" "Non-null output" "No computers found"
} else {
    $computerName = $computers[0].computerName
    Write-Host "Using computer: $computerName" -ForegroundColor Gray

    # ── A1: ActiveScan ──
    $results.A1 = T "A1" "ActiveScan" `
        { Start-SEPScan -ComputerName $computerName -ActiveScan } `
        { param($r) $r -ne $null }

    # ── A2: FullScan ──
    $results.A2 = T "A2" "FullScan" `
        { Start-SEPScan -ComputerName $computerName -FullScan } `
        { param($r) $r -ne $null }

    # ── A3: Pipeline input ──
    $results.A3 = T "A3" "Pipeline input" `
        { $computerName | Start-SEPScan -ActiveScan } `
        { param($r) $r -ne $null }

    # ── A4: Invalid computer name (should not throw, returns gracefully) ──
    $results.A4 = T "A4" "Invalid computer handled" `
        {
            $errs = $null
            Start-SEPScan -ComputerName 'NonExistentComputer12345' -ActiveScan -ErrorVariable errs -ErrorAction SilentlyContinue
            $true  # The test passes if it doesn't throw; result may be empty
        } `
        { param($r) $r -eq $true }

    # ── A5: Non-null output ──
    $results.A5 = T "A5" "Non-null output" `
        { Start-SEPScan -ComputerName $computerName -ActiveScan } `
        { param($r) $r -ne $null }
}

# === Summary ===
Write-Host "`n========== SUMMARY (PS7) ==========" -ForegroundColor Yellow
$pass = 0; $fail = 0; $skip = 0
foreach ($k in $results.Keys | Sort-Object) {
    $v = $results[$k]
    if ($v -eq "PASS") { $pass++; Write-Host "  $k : PASS" -ForegroundColor Green }
    elseif ($v -eq "SKIP") { $skip++; Write-Host "  $k : SKIP" -ForegroundColor Yellow }
    else { $fail++; Write-Host "  $k : FAIL" -ForegroundColor Red }
}
Write-Host "TOTAL: $($pass+$fail+$skip) tests, $pass pass, $fail fail, $skip skip" -ForegroundColor Yellow

if ($fail -gt 0) { exit 1 }
