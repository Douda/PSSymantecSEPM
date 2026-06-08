# Smoke verification for HostGroups seed (PS7)
# Usage: pwsh -NoProfile -File Scripts/Smoke/Seed-HostGroups/batch.ps7.ps1

$ErrorActionPreference = "Continue"

$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"

Write-Host "=== Smoke: Seed HostGroups (PS7) ==="

$seedScript = Join-Path -Path $RepoRoot -ChildPath 'Scripts/Seed-SEPMData.ps1'
$seedNames = @('Corporate LAN', 'DMZ Servers')

# ── Clean state: delete existing seed host groups if any (DELETE is 500, so we warn) ──
$s = Initialize-SEPMSession
$summary = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/policy-objects/hostgroups/summary" -Headers $s.Headers -SkipCert:$s.SkipCert
$content = if ($summary.ContainsKey('content')) { $summary.content } else { $summary }
if ($content) {
    foreach ($p in $content) {
        if ($p.name -in $seedNames) {
            $delResp = Invoke-SepmApi -Method DELETE -Uri "$($s.BaseURLv1)/policies/policy-objects/hostgroups/$($p.id)" -Headers $s.Headers -SkipCert:$s.SkipCert
            if ($delResp -is [string] -and $delResp -like 'Error:*') {
                Write-Host "  NOTE: DELETE failed for $($p.name) (API limitation). Will recreate via Force."
            }
        }
    }
}

# ── Baseline after cleanup ──
$s = Initialize-SEPMSession
$beforeSummary = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/policy-objects/hostgroups/summary" -Headers $s.Headers -SkipCert:$s.SkipCert
$beforeContent = if ($beforeSummary.ContainsKey('content')) { $beforeSummary.content } else { $beforeSummary }
$beforeCount = if ($beforeContent) { $beforeContent.Count } else { 0 }
Write-Host "Before: $beforeCount host groups"

# ── Seed ──
Write-Host "--- Seeding HostGroups ---"
$result = & $seedScript -Categories HostGroups 6>&1

$outputText = if ($result -is [array]) { $result -join "`n" } else { $result.ToString() }
if ($outputText -notmatch 'Host groups seeded: 2') {
    throw "FAIL: expected 'Host groups seeded: 2', got: $outputText"
}

# Rebuild module output (seed script may have used -Force import)
Import-Module "$RepoRoot/Output/PSSymantecSEPM/PSSymantecSEPM.psm1" -Force
& (Get-Module PSSymantecSEPM) { $script:SkipCert = $true }

# ── Verify count: at least 2 (seed adds if missing, skips if exists) ──
$s = Initialize-SEPMSession
$afterSummary = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/policy-objects/hostgroups/summary" -Headers $s.Headers -SkipCert:$s.SkipCert
$afterContent = if ($afterSummary.ContainsKey('content')) { $afterSummary.content } else { $afterSummary }
$afterCount = if ($afterContent) { $afterContent.Count } else { 0 }
Write-Host "After: $afterCount host groups"
if ($afterCount -lt 2) {
    throw "FAIL: expected at least 2 host groups, got $afterCount"
}

# ── Verify host group names ──
$hgNames = if ($afterContent) { $afterContent.name } else { @() }
$seedNames | ForEach-Object {
    if ($_ -notin $hgNames) { throw "FAIL: host group '$_' not found" }
}
Write-Host "  Both host group names present"

# Helper: get full host group by name
function Get-HostGroupByName($name) {
    $s = Initialize-SEPMSession
    $sum = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/policy-objects/hostgroups/summary" -Headers $s.Headers -SkipCert:$s.SkipCert
    $c = if ($sum.ContainsKey('content')) { $sum.content } else { $sum }
    $match = $c | Where-Object { $_.name -eq $name } | Select-Object -First 1
    if (-not $match) { return $null }
    return Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/policy-objects/hostgroups/$($match.id)" -Headers $s.Headers -SkipCert:$s.SkipCert
}

# ── Verify Corporate LAN ──
Write-Host "--- Verify Corporate LAN ---"
$cl = Get-HostGroupByName 'Corporate LAN'
if (-not $cl) { throw "FAIL: Corporate LAN not found" }
if ($cl.name -ne 'Corporate LAN') { throw "FAIL: Corporate LAN name mismatch: $($cl.name)" }
$hostCount = if ($cl.hosts -and $cl.hosts.Count) { $cl.hosts.Count } else { 0 }
if ($hostCount -ne 3) { throw "FAIL: Corporate LAN should have 3 hosts, got $hostCount" }
Write-Host "  Corporate LAN: name=$($cl.name) hosts=$hostCount - PASS"

# Verify host types
$types = @()
foreach ($h in $cl.hosts) {
    if ($h -is [hashtable]) {
        $types += if ($h.ContainsKey('ip')) { 'ip' }
                  elseif ($h.ContainsKey('ipv4_subnet')) { 'ipv4_subnet' }
                  else { 'unknown' }
    } elseif ($h -is [pscustomobject]) {
        $types += if ($h.PSObject.Properties.Name -contains 'ip') { 'ip' }
                  elseif ($h.PSObject.Properties.Name -contains 'ipv4_subnet') { 'ipv4_subnet' }
                  else { 'unknown' }
    }
}
$subnetCount = ($types | Where-Object { $_ -eq 'ipv4_subnet' }).Count
$ipCount = ($types | Where-Object { $_ -eq 'ip' }).Count
if ($subnetCount -ne 2) { throw "FAIL: Corporate LAN should have 2 subnets, got $subnetCount" }
if ($ipCount -ne 1) { throw "FAIL: Corporate LAN should have 1 IP, got $ipCount" }
Write-Host "  Corporate LAN host types: $subnetCount subnets, $ipCount IP - PASS"

# ── Verify DMZ Servers ──
Write-Host "--- Verify DMZ Servers ---"
$dmz = Get-HostGroupByName 'DMZ Servers'
if (-not $dmz) { throw "FAIL: DMZ Servers not found" }
$hostCount = if ($dmz.hosts -and $dmz.hosts.Count) { $dmz.hosts.Count } else { 0 }
if ($hostCount -ne 2) { throw "FAIL: DMZ Servers should have 2 hosts, got $hostCount" }
Write-Host "  DMZ Servers: name=$($dmz.name) hosts=$hostCount - PASS"

$types = @()
foreach ($h in $dmz.hosts) {
    if ($h -is [hashtable]) {
        $types += if ($h.ContainsKey('ip')) { 'ip' }
                  elseif ($h.ContainsKey('ipv4_subnet')) { 'ipv4_subnet' }
                  else { 'unknown' }
    } elseif ($h -is [pscustomobject]) {
        $types += if ($h.PSObject.Properties.Name -contains 'ip') { 'ip' }
                  elseif ($h.PSObject.Properties.Name -contains 'ipv4_subnet') { 'ipv4_subnet' }
                  else { 'unknown' }
    }
}
$subnetCount = ($types | Where-Object { $_ -eq 'ipv4_subnet' }).Count
$ipCount = ($types | Where-Object { $_ -eq 'ip' }).Count
if ($subnetCount -ne 1) { throw "FAIL: DMZ Servers should have 1 subnet, got $subnetCount" }
if ($ipCount -ne 1) { throw "FAIL: DMZ Servers should have 1 IP, got $ipCount" }
Write-Host "  DMZ Servers host types: $subnetCount subnets, $ipCount IP - PASS"

# ── Idempotency ──
Write-Host "--- Idempotency ---"
$s = Initialize-SEPMSession
$idemSummary = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/policy-objects/hostgroups/summary" -Headers $s.Headers -SkipCert:$s.SkipCert
$idemContent = if ($idemSummary.ContainsKey('content')) { $idemSummary.content } else { $idemSummary }
$idemBefore = if ($idemContent) { $idemContent.Count } else { 0 }
$result = & $seedScript -Categories HostGroups 6>&1
Import-Module "$RepoRoot/Output/PSSymantecSEPM/PSSymantecSEPM.psm1" -Force
& (Get-Module PSSymantecSEPM) { $script:SkipCert = $true }
$s = Initialize-SEPMSession
$idemSummary2 = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/policy-objects/hostgroups/summary" -Headers $s.Headers -SkipCert:$s.SkipCert
$idemContent2 = if ($idemSummary2.ContainsKey('content')) { $idemSummary2.content } else { $idemSummary2 }
$idemAfter = if ($idemContent2) { $idemContent2.Count } else { 0 }
if ($idemAfter -ne $idemBefore) { throw "FAIL: count changed ($idemBefore -> $idemAfter)" }
Write-Host "  Idempotent: $idemAfter host groups - PASS"

Write-Host "`n=== Smoke: Seed HostGroups (PS7) — ALL PASS ===" -ForegroundColor Green
