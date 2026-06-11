# Smoke verification for Get-SEPMIpsPolicy (PS7)
# Usage: pwsh -NoProfile -File Scripts/Smoke/Get-SEPMIpsPolicy/batch.ps7.ps1

[CmdletBinding()]param()

$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"

Write-Host "=== Smoke: Get-SEPMIpsPolicy (PS7) ===" -ForegroundColor Yellow

$results = @{}

# ── A1: Retrieve IPS policy by name ──
$results.A1 = T "A1" "Get-SEPMIpsPolicy by name returns IPS policy" `
    { Get-SEPMIpsPolicy -PolicyName "Intrusion Prevention policy" } `
    { param($r)
        $r -ne $null -and
        $r.name -eq 'Intrusion Prevention policy' -and
        $null -ne $r.enabled
    }

# ── Summary ──
Write-Host "`n========== SUMMARY (PS7) ==========" -ForegroundColor Yellow
$pass = 0; $fail = 0
foreach ($k in $results.Keys | Sort-Object) {
    $v = $results[$k]
    if ($v -eq "PASS") { $pass++; Write-Host "  $k : PASS" -ForegroundColor Green }
    else { $fail++; Write-Host "  $k : FAIL" -ForegroundColor Red }
}
Write-Host "TOTAL: $($pass+$fail) tests, $pass pass, $fail fail" -ForegroundColor Yellow
