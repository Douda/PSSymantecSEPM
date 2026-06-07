# Smoke batch: locations GET cmdlets (PS 5.1)
# Covers: Get-SEPMLocation, Get-SEPMLocationXML
# Deploy: cp -r ./Output/PSSymantecSEPM /home/.../Windows/PSSymantecSEPM
# Run via WinRM: python3 Scripts/invoke-winrm.py 'C:\...\batch.ps51.ps1'

$ErrorActionPreference = "Continue"
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

$d = "$env:APPDATA\PSSymantecSEPM"
New-Item -ItemType Directory $d -Force | Out-Null
@{port=8446;ServerAddress="localhost"} | ConvertTo-Json | Set-Content "$d\config.json" -Force

Import-Module "$env:USERPROFILE\Desktop\Shared\PSSymantecSEPM\PSSymantecSEPM.psm1" -Force
$mod = Get-Module PSSymantecSEPM
& $mod { $script:SkipCert = $true }

function T {
    param($Id, $Label, [ScriptBlock]$Action, [ScriptBlock]$Assert)
    Write-Host "--- $Id : $Label ---" -ForegroundColor Cyan
    try {
        $result = & $Action
        if ($result -is [string] -and $result -like "Error:*") {
            Write-Host "  VERDICT: FAIL (API error)" -ForegroundColor Red
            return "FAIL"
        }
        $ok = & $Assert $result
        if ($ok) { Write-Host "  VERDICT: PASS" -ForegroundColor Green; return "PASS" }
        else     { Write-Host "  VERDICT: FAIL" -ForegroundColor Red;   return "FAIL" }
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        return "FAIL"
    }
}

$results = @{}

# ── Discovery ──
$groups = Get-SEPMGroups
if (-not $groups -or $groups.Count -eq 0) {
    Write-Error "No groups found — cannot test locations"
    exit 1
}
$GROUP_ID = $groups[0].id
Write-Host "Group: $($groups[0].name) ($GROUP_ID)" -ForegroundColor Gray

$results.C1 = T "C1" "Get-SEPMLocation -GroupID" `
    { Get-SEPMLocation -GroupID $GROUP_ID } `
    { param($r) $r -ne $null -and $r.Count -gt 0 -and $r[0].locationName -ne $null }

$results.C2 = T "C2" "Get-SEPMGroups | Get-SEPMLocation" `
    { $groups | Select-Object -First 1 | Get-SEPMLocation } `
    { param($r) $r -ne $null -and $r.Count -gt 0 }

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
Write-Host "`n========== SUMMARY (PS5.1 Locations) ==========" -ForegroundColor Yellow
$pass = 0; $fail = 0
foreach ($k in $results.Keys | Sort-Object) {
    $v = $results[$k]
    if ($v -eq "PASS") { $pass++; Write-Host "  $k : PASS" -ForegroundColor Green }
    else { $fail++; Write-Host "  $k : FAIL" -ForegroundColor Red }
}
Write-Host "TOTAL: $($pass+$fail) tests, $pass pass, $fail fail" -ForegroundColor Yellow