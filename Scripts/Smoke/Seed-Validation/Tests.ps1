<#
.SYNOPSIS
    Shared smoke tests for Seed-Validation.

.DESCRIPTION
    Dot-sourced by run.ps7.ps1 and run.ps51.ps1 after Common.ps1.
    Validates that all seed categories were correctly created after a full seeding run.
#>

Write-Host "=== Smoke: Seed-Validation ==="

# ── Private function wrappers (module-scope tunnel) ──
$script:__SepmModule = Get-Module PSSymantecSEPM

function Invoke-SepmApi {
    & $script:__SepmModule { Invoke-SepmApi @args } @args
}
function Initialize-SEPMSession {
    & $script:__SepmModule { Initialize-SEPMSession @args } @args
}

# Helper: normalize summary content (handles ConvertTo-Hashtable collapsing 1-element arrays)
function Get-SummaryContent($response) {
    $content = if ($response.ContainsKey('content')) { $response.content } else { $response }
    if ($content -is [hashtable] -and $content.ContainsKey('id')) {
        return @($content)
    }
    return $content
}

$results = @{}

# ── A1: Group count >= 80 ──
$results.A1 = T "A1" "Group count >= 80" `
    { Get-SEPMGroups } `
    { param($r) $r.Count -ge 80 }

# ── A2: 3 regions (EMEA, NA, APJ) as direct children of My Company ──
$results.A2 = T "A2" "3 regions (EMEA, NA, APJ) under My Company" `
    { Get-SEPMGroups } `
    { param($groups)
        $regions = @('EMEA', 'NA', 'APJ')
        $found = 0
        foreach ($r in $regions) {
            $match = $groups | Where-Object { $_.fullPathName -eq "My Company\$r" }
            if ($match) { $found++ }
        }
        $found -ge 3
    }

# ── A3: Administrators >= 6 ──
$results.A3 = T "A3" "Administrators >= 6" `
    { Get-SEPMAdmins } `
    { param($r) $r.Count -ge 6 }

# ── A4: Exceptions policies >= 4 ──
$results.A4 = T "A4" "Exceptions policies >= 4" `
    {
        $s = Initialize-SEPMSession
        $summary = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/exceptions" -Headers $s.Headers -SkipCert:$s.SkipCert
        Get-SummaryContent $summary
    } `
    { param($r) if ($r) { $r.Count -ge 4 } else { $false } }

# ── A5: MEM policies >= 4 ──
$results.A5 = T "A5" "MEM policies >= 4" `
    {
        $s = Initialize-SEPMSession
        $summary = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/mem" -Headers $s.Headers -SkipCert:$s.SkipCert
        Get-SummaryContent $summary
    } `
    { param($r) if ($r) { $r.Count -ge 4 } else { $false } }

# ── A6: Upgrade policies >= 3 ──
$results.A6 = T "A6" "Upgrade policies >= 3" `
    {
        $s = Initialize-SEPMSession
        $summary = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/upgrade" -Headers $s.Headers -SkipCert:$s.SkipCert
        Get-SummaryContent $summary
    } `
    { param($r) if ($r) { $r.Count -ge 3 } else { $false } }

# ── A7: TDAD policies >= 2 ──
$results.A7 = T "A7" "TDAD policies >= 2" `
    {
        $s = Initialize-SEPMSession
        $summary = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/tdad" -Headers $s.Headers -SkipCert:$s.SkipCert
        Get-SummaryContent $summary
    } `
    { param($r) if ($r) { $r.Count -ge 2 } else { $false } }

# ── A8: Host Groups >= 2 (Corporate LAN, DMZ Servers) ──
$results.A8 = T "A8" "Host Groups >= 2" `
    {
        $s = Initialize-SEPMSession
        $summary = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/policy-objects/hostgroups/summary" -Headers $s.Headers -SkipCert:$s.SkipCert
        Get-SummaryContent $summary
    } `
    { param($r) if ($r) { $r.Count -ge 2 } else { $false } }

# ── A9: Fingerprint lists >= 2 (Known Malware Hashes, Approved Binaries) ──
$results.A9 = T "A9" "Fingerprint lists >= 2" `
    {
        $seedNames = @('Known Malware Hashes', 'Approved Binaries')
        $found = @()
        foreach ($name in $seedNames) {
            try {
                $fp = Get-SEPMFileFingerprintList -FingerprintListName $name -ErrorAction SilentlyContinue
                if ($fp -and $fp.name) { $found += $fp }
            } catch { }
        }
        $found
    } `
    { param($r) $r.Count -ge 2 }

# ── A10: Policies assigned to groups >= 10 ──
$results.A10 = T "A10" "Policies assigned to groups >= 10" `
    {
        $policies = Get-SEPMPoliciesSummary
        $assigned = 0
        foreach ($p in $policies) {
            if ($p.assignedtolocations -and $p.assignedtolocations.Count -gt 0) {
                $assigned += $p.assignedtolocations.Count
            }
        }
        $assigned
    } `
    { param($r) $r -ge 10 }

# ── Summary ──
Write-Summary -Results $results -Label "Seed-Validation Smoke Tests"
