<#
.SYNOPSIS
    Shared smoke tests for Seed-HostGroups.

.DESCRIPTION
    Dot-sourced by run.ps7.ps1 and run.ps51.ps1 after Common.ps1.
    Cleans old host groups, seeds 2 groups, verifies config details,
    and tests idempotency.
#>

Write-Host "=== Smoke: Seed HostGroups ==="

# ── Private function wrappers (module-scope tunnel) ──
$script:__SepmModule = Get-Module PSSymantecSEPM

function Invoke-SepmApi {
    & $script:__SepmModule { Invoke-SepmApi @args } @args
}
function Initialize-SEPMSession {
    & $script:__SepmModule { Initialize-SEPMSession @args } @args
}

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

# Helper function
function Get-HostGroupByName($name) {
    $s = Initialize-SEPMSession
    $sum = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/policy-objects/hostgroups/summary" -Headers $s.Headers -SkipCert:$s.SkipCert
    $c = if ($sum.ContainsKey('content')) { $sum.content } else { $sum }
    $match = $c | Where-Object { $_.name -eq $name } | Select-Object -First 1
    if (-not $match) { return $null }
    return Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/policy-objects/hostgroups/$($match.id)" -Headers $s.Headers -SkipCert:$s.SkipCert
}

$results = @{}

# ── A1: Baseline count (before seed) ──
$results.A1 = & {
    try {
        $s = Initialize-SEPMSession
        $beforeSummary = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/policy-objects/hostgroups/summary" -Headers $s.Headers -SkipCert:$s.SkipCert
        $beforeContent = if ($beforeSummary.ContainsKey('content')) { $beforeSummary.content } else { $beforeSummary }
        $beforeCount = if ($beforeContent) { $beforeContent.Count } else { 0 }
        Write-Host "  Before: $beforeCount host groups"
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── A2: Seed output ──
$results.A2 = & {
    try {
        $result = & $seedScript -Categories HostGroups 6>&1
        $outputText = if ($result -is [array]) { $result -join "`n" } else { $result.ToString() }
        if ($outputText -notmatch 'Host groups seeded: 2') {
            throw "expected 'Host groups seeded: 2', got: $outputText"
        }
        Write-Host "  VERDICT: PASS" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── A3: Count >= 2 ──
$results.A3 = & {
    try {
        $s = Initialize-SEPMSession
        $afterSummary = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/policy-objects/hostgroups/summary" -Headers $s.Headers -SkipCert:$s.SkipCert
        $afterContent = if ($afterSummary.ContainsKey('content')) { $afterSummary.content } else { $afterSummary }
        $afterCount = if ($afterContent) { $afterContent.Count } else { 0 }
        Write-Host "  After: $afterCount host groups"
        if ($afterCount -lt 2) { throw "expected at least 2 host groups, got $afterCount" }
        Write-Host "  VERDICT: PASS" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── A4: Both host group names present ──
$results.A4 = & {
    try {
        $s = Initialize-SEPMSession
        $afterSummary = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/policy-objects/hostgroups/summary" -Headers $s.Headers -SkipCert:$s.SkipCert
        $afterContent = if ($afterSummary.ContainsKey('content')) { $afterSummary.content } else { $afterSummary }
        $hgNames = if ($afterContent) { $afterContent.name } else { @() }
        foreach ($n in $seedNames) {
            if ($n -notin $hgNames) { throw "host group '$n' not found" }
        }
        Write-Host "  Both host group names present - PASS" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── A5: Verify Corporate LAN ──
$results.A5 = & {
    try {
        Write-Host "--- Verify Corporate LAN ---"
        $cl = Get-HostGroupByName 'Corporate LAN'
        if (-not $cl) { throw "Corporate LAN not found" }
        if ($cl.name -ne 'Corporate LAN') { throw "Corporate LAN name mismatch: $($cl.name)" }
        $hostCount = if ($cl.hosts -and $cl.hosts.Count) { $cl.hosts.Count } else { 0 }
        if ($hostCount -ne 3) { throw "Corporate LAN should have 3 hosts, got $hostCount" }
        Write-Host "  Corporate LAN: name=$($cl.name) hosts=$hostCount - PASS" -ForegroundColor Green

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
        if ($subnetCount -ne 2) { throw "Corporate LAN should have 2 subnets, got $subnetCount" }
        if ($ipCount -ne 1) { throw "Corporate LAN should have 1 IP, got $ipCount" }
        Write-Host "  Corporate LAN host types: $subnetCount subnets, $ipCount IP - PASS" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── A6: Verify DMZ Servers ──
$results.A6 = & {
    try {
        Write-Host "--- Verify DMZ Servers ---"
        $dmz = Get-HostGroupByName 'DMZ Servers'
        if (-not $dmz) { throw "DMZ Servers not found" }
        $hostCount = if ($dmz.hosts -and $dmz.hosts.Count) { $dmz.hosts.Count } else { 0 }
        if ($hostCount -ne 2) { throw "DMZ Servers should have 2 hosts, got $hostCount" }
        Write-Host "  DMZ Servers: name=$($dmz.name) hosts=$hostCount - PASS" -ForegroundColor Green

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
        if ($subnetCount -ne 1) { throw "DMZ Servers should have 1 subnet, got $subnetCount" }
        if ($ipCount -ne 1) { throw "DMZ Servers should have 1 IP, got $ipCount" }
        Write-Host "  DMZ Servers host types: $subnetCount subnets, $ipCount IP - PASS" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── A7: Idempotency ──
$results.A7 = & {
    try {
        Write-Host "--- Idempotency ---"
        $s = Initialize-SEPMSession
        $idemSummary = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/policy-objects/hostgroups/summary" -Headers $s.Headers -SkipCert:$s.SkipCert
        $idemContent = if ($idemSummary.ContainsKey('content')) { $idemSummary.content } else { $idemSummary }
        $idemBefore = if ($idemContent) { $idemContent.Count } else { 0 }
        $result = & $seedScript -Categories HostGroups 6>&1
        $s = Initialize-SEPMSession
        $idemSummary2 = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/policy-objects/hostgroups/summary" -Headers $s.Headers -SkipCert:$s.SkipCert
        $idemContent2 = if ($idemSummary2.ContainsKey('content')) { $idemSummary2.content } else { $idemSummary2 }
        $idemAfter = if ($idemContent2) { $idemContent2.Count } else { 0 }
        if ($idemAfter -ne $idemBefore) { throw "count changed ($idemBefore -> $idemAfter)" }
        Write-Host "  Idempotent: $idemAfter host groups - PASS" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── Summary ──
Write-Summary -Results $results -Label "Seed HostGroups Smoke Tests"
