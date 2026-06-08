# Smoke verification for HostGroups seed (PS 5.1)
# Usage: via WinRM — python3 Scripts/invoke-winrm.py 'C:\Users\smokeuser\Desktop\Shared\smoke-hostgroups.ps1'

$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"
. "$RepoRoot\Common-PS51.ps1"

Write-Host "=== Smoke: Seed HostGroups (PS5.1) ==="

$seedScript = Join-Path -Path $RepoRoot -ChildPath 'Seed-SEPMData.ps1'
$seedNames = @('Corporate LAN', 'DMZ Servers')

# ── Connect ──
$s = Initialize-SEPMSession
$headers = $s.Headers
$skipCert = $s.SkipCert
$baseV1 = $s.BaseURLv1

# ── Baseline ──
$beforeSummary = Invoke-SepmApi -Method GET -Uri "$baseV1/policies/policy-objects/hostgroups/summary" -Headers $headers -SkipCert:$skipCert
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

# Re-import module (seed script may have used -Force import)
Import-Module "$RepoRoot\PSSymantecSEPM\PSSymantecSEPM.psm1" -Force
$s = Initialize-SEPMSession
$headers = $s.Headers
$skipCert = $s.SkipCert
$baseV1 = $s.BaseURLv1

# ── Verify count: at least 2 (seed adds if missing, skips if exists) ──
$afterSummary = Invoke-SepmApi -Method GET -Uri "$baseV1/policies/policy-objects/hostgroups/summary" -Headers $headers -SkipCert:$skipCert
$afterContent = if ($afterSummary.ContainsKey('content')) { $afterSummary.content } else { $afterSummary }
$afterCount = if ($afterContent) { $afterContent.Count } else { 0 }
Write-Host "After: $afterCount host groups"
if ($afterCount -lt 2) {
    throw "FAIL: expected at least 2 host groups, got $afterCount"
}

# ── Verify host group names ──
$hgNames = if ($afterContent) { $afterContent.name } else { @() }
foreach ($n in $seedNames) {
    if ($n -notin $hgNames) { throw "FAIL: host group '$n' not found" }
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
if ($cl.name -ne 'Corporate LAN') { throw "FAIL: Corporate LAN name mismatch" }
$hostCount = if ($cl.hosts) { if ($cl.hosts.Count) { $cl.hosts.Count } else { 1 } } else { 0 }
if ($hostCount -ne 3) { throw "FAIL: Corporate LAN should have 3 hosts, got $hostCount" }
Write-Host "  Corporate LAN: hosts=$hostCount - PASS"

# ── Verify DMZ Servers ──
Write-Host "--- Verify DMZ Servers ---"
$dmz = Get-HostGroupByName 'DMZ Servers'
if (-not $dmz) { throw "FAIL: DMZ Servers not found" }
$hostCount = if ($dmz.hosts) { if ($dmz.hosts.Count) { $dmz.hosts.Count } else { 1 } } else { 0 }
if ($hostCount -ne 2) { throw "FAIL: DMZ Servers should have 2 hosts, got $hostCount" }
Write-Host "  DMZ Servers: hosts=$hostCount - PASS"

# ── Idempotency ──
Write-Host "--- Idempotency ---"
$before = $afterCount
$result = & $seedScript -Categories HostGroups 6>&1
Import-Module "$RepoRoot\PSSymantecSEPM\PSSymantecSEPM.psm1" -Force
$s = Initialize-SEPMSession
$idemSummary = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/policy-objects/hostgroups/summary" -Headers $s.Headers -SkipCert:$s.SkipCert
$idemContent = if ($idemSummary.ContainsKey('content')) { $idemSummary.content } else { $idemSummary }
$idemAfter = if ($idemContent) { $idemContent.Count } else { 0 }
if ($idemAfter -ne $before) { throw "FAIL: count changed ($before -> $idemAfter)" }
Write-Host "  Idempotent: $idemAfter host groups - PASS"

Write-Host "`n=== Smoke: Seed HostGroups (PS5.1) — ALL PASS ===" -ForegroundColor Green
