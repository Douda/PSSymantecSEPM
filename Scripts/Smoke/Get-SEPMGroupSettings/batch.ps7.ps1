# Smoke verification for Get-SEPMGroupSettings (PS7)
# Usage: pwsh -NoProfile -File Scripts/Smoke/Get-SEPMGroupSettings/batch.ps7.ps1

[CmdletBinding()]param()

$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"

Write-Host "=== Smoke: Get-SEPMGroupSettings (PS7) ===" -ForegroundColor Yellow

$results = @{}

$groupId = '1FB75121AC1E0002790C7332FFCDE857'
$locationId = '3BB37557AC1E00020BD263CF8AE23291'

# ── A1: Retrieve group settings for a group/location ──
$results.A1 = T "A1" "Get-SEPMGroupSettings returns settings for group+location" `
    { Get-SEPMGroupSettings -groupId $groupId -locationId $locationId } `
    { param($r)
        $r -ne $null
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
