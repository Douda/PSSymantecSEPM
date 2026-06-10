# Smoke batch: locations GET cmdlets (PS7)
# Covers: Get-SEPMLocation, Get-SEPMLocationXML
# Usage: pwsh -NoProfile -File Scripts/Smoke/Get-SEPMLocations/batch.ps7.ps1

$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"

$results = @{}

# ── Discovery ──
$groups = Get-SEPMGroups
if (-not $groups -or $groups.Count -eq 0) {
    Write-Error "No groups found — cannot test locations"
    exit 1
}
$GROUP_ID = $groups[0].id
Write-Host "Group: $($groups[0].name) ($GROUP_ID)" -ForegroundColor Gray

# ── C1: Get-SEPMLocation -GroupID ──
$results.C1 = T "C1" "Get-SEPMLocation -GroupID" `
    { Get-SEPMLocation -GroupID $GROUP_ID } `
    { param($r) $r -ne $null -and $r.Count -gt 0 -and $r[0].locationName -ne $null }

# ── C2: Pipeline ──
$results.C2 = T "C2" "Get-SEPMGroups | Get-SEPMLocation" `
    { $groups | Select-Object -First 1 | Get-SEPMLocation } `
    { param($r) $r -ne $null -and $r.Count -gt 0 }

# ── Discover location for XML ──
$locs = Get-SEPMLocation -GroupID $GROUP_ID
if ($locs -and $locs.Count -gt 0) {
    $LOC_ID = $locs[0].locationId
    Write-Host "Location: $($locs[0].locationName) ($LOC_ID)" -ForegroundColor Gray

    $results.C3 = T "C3" "Get-SEPMLocationXML" `
        { Get-SEPMLocationXML -GroupID $GROUP_ID -LocationID $LOC_ID } `
        { param($r) $r -ne $null }
} else {
    Write-Error "No locations found in group"
}

# === Summary ===
Write-Host "`n========== SUMMARY (PS7 Locations) ==========" -ForegroundColor Yellow
$pass = 0; $fail = 0
foreach ($k in $results.Keys | Sort-Object) {
    $v = $results[$k]
    if ($v -eq "PASS") { $pass++; Write-Host "  $k : PASS" -ForegroundColor Green }
    else { $fail++; Write-Host "  $k : FAIL" -ForegroundColor Red }
}
Write-Host "TOTAL: $($pass+$fail) tests, $pass pass, $fail fail" -ForegroundColor Yellow
