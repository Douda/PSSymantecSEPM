# Smoke batch: Get-SEPMVersion (PS7)
# Usage: pwsh -NoProfile -File Scripts/Smoke/Get-SEPMVersion/batch.ps7.ps1

$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"

$results = @{}

# ── A1: Get-SEPMVersion ──
$results.A1 = T "A1" "Get-SEPMVersion" `
    { Get-SEPMVersion } `
    { param($r) $r -ne $null -and $r.API_SEQUENCE -ne $null -and $r.API_VERSION -ne $null -and $r.version -ne $null }

# === Summary ===
Write-Host "`n========== SUMMARY (PS7 Get-SEPMVersion) ==========" -ForegroundColor Yellow
$pass = 0; $fail = 0
foreach ($k in $results.Keys | Sort-Object) {
    $v = $results[$k]
    if ($v -eq "PASS") { $pass++; Write-Host "  $k : PASS" -ForegroundColor Green }
    else { $fail++; Write-Host "  $k : FAIL" -ForegroundColor Red }
}
Write-Host "TOTAL: $($pass+$fail) tests, $pass pass, $fail fail" -ForegroundColor Yellow
