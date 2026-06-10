# Smoke: Seed-Validation — aggregate existence + count checks (PS5.1)
# Validates that all seed categories were correctly created after a full seeding run.
# Deploy to shared volume, then run via:
#   python3 Scripts/invoke-winrm.py 'C:\Users\smokeuser\Desktop\Shared\smoke-validation.batch.ps1'

$ErrorActionPreference = "Continue"

$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"
. "$RepoRoot\Common-PS51.ps1"

Write-Host "=== Smoke: Seed-Validation (PS5.1) ==="

# Helper: normalize summary content (handles hashtable responses from ConvertTo-Hashtable)
function Get-SummaryContent($response) {
    if ($response -is [hashtable]) {
        if ($response.ContainsKey('content')) {
            $content = $response['content']
            if ($content -ne $null) {
                if ($content -is [array]) { return $content }
                if ($content -is [hashtable] -and $content.ContainsKey('id')) { return @($content) }
                return @($content)
            }
        }
        if ($response.ContainsKey('id')) { return @($response) }
        return @()
    }
    return $response
}

$passCount = 0
$failCount = 0

# ── A1: Group count >= 80 ──
Write-Host "--- A1 : Group count >= 80 ---" -ForegroundColor Cyan
try {
    Import-Module "$RepoRoot\PSSymantecSEPM\PSSymantecSEPM.psm1" -Force
    & (Get-Module PSSymantecSEPM) { $script:SkipCert = $true }
    $groups = Get-SEPMGroups
    $count = if ($groups -is [array]) { $groups.Count } else { 1 }
    if ($count -lt 80) { throw "FAIL: expected >= 80, got $count" }
    Write-Host "  VERDICT: PASS (count=$count)"
    $passCount++
} catch {
    Write-Host "  VERDICT: FAIL ($($_.Exception.Message))" -ForegroundColor Red
    $failCount++
}

# ── A2: 3 regions (EMEA, NA, APJ) as direct children of My Company ──
Write-Host "--- A2 : 3 regions (EMEA, NA, APJ) under My Company ---" -ForegroundColor Cyan
try {
    Import-Module "$RepoRoot\PSSymantecSEPM\PSSymantecSEPM.psm1" -Force
    & (Get-Module PSSymantecSEPM) { $script:SkipCert = $true }
    $groups = Get-SEPMGroups
    $regionNames = @('EMEA', 'NA', 'APJ')
    $found = 0
    foreach ($r in $regionNames) {
        foreach ($g in $groups) {
            $fpn = if ($g -is [hashtable]) { $g['fullPathName'] } else { $g.fullPathName }
            if ($fpn -eq "My Company\$r") { $found++; break }
        }
    }
    if ($found -lt 3) { throw "FAIL: expected 3 regions, found $found" }
    Write-Host "  VERDICT: PASS (found $found/3 regions)"
    $passCount++
} catch {
    Write-Host "  VERDICT: FAIL ($($_.Exception.Message))" -ForegroundColor Red
    $failCount++
}

# ── A3: Administrators >= 6 ──
Write-Host "--- A3 : Administrators >= 6 ---" -ForegroundColor Cyan
try {
    Import-Module "$RepoRoot\PSSymantecSEPM\PSSymantecSEPM.psm1" -Force
    & (Get-Module PSSymantecSEPM) { $script:SkipCert = $true }
    $admins = Get-SEPMAdmins
    $count = if ($admins -is [array]) { $admins.Count } else { 1 }
    if ($count -lt 6) { throw "FAIL: expected >= 6, got $count" }
    Write-Host "  VERDICT: PASS (count=$count)"
    $passCount++
} catch {
    Write-Host "  VERDICT: FAIL ($($_.Exception.Message))" -ForegroundColor Red
    $failCount++
}

# ── A4: Exceptions policies >= 4 ──
Write-Host "--- A4 : Exceptions policies >= 4 ---" -ForegroundColor Cyan
try {
    Import-Module "$RepoRoot\PSSymantecSEPM\PSSymantecSEPM.psm1" -Force
    & (Get-Module PSSymantecSEPM) { $script:SkipCert = $true }
    $s = Initialize-SEPMSession
    $summary = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/exceptions" -Headers $s.Headers -SkipCert:$s.SkipCert
    $content = Get-SummaryContent $summary
    $count = if ($content) { $content.Count } else { 0 }
    if ($count -lt 4) { throw "FAIL: expected >= 4, got $count" }
    Write-Host "  VERDICT: PASS (count=$count)"
    $passCount++
} catch {
    Write-Host "  VERDICT: FAIL ($($_.Exception.Message))" -ForegroundColor Red
    $failCount++
}

# ── A5: MEM policies >= 4 ──
Write-Host "--- A5 : MEM policies >= 4 ---" -ForegroundColor Cyan
try {
    Import-Module "$RepoRoot\PSSymantecSEPM\PSSymantecSEPM.psm1" -Force
    & (Get-Module PSSymantecSEPM) { $script:SkipCert = $true }
    $s = Initialize-SEPMSession
    $summary = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/mem" -Headers $s.Headers -SkipCert:$s.SkipCert
    $content = Get-SummaryContent $summary
    $count = if ($content) { $content.Count } else { 0 }
    if ($count -lt 4) { throw "FAIL: expected >= 4, got $count" }
    Write-Host "  VERDICT: PASS (count=$count)"
    $passCount++
} catch {
    Write-Host "  VERDICT: FAIL ($($_.Exception.Message))" -ForegroundColor Red
    $failCount++
}

# ── A6: Upgrade policies >= 3 ──
Write-Host "--- A6 : Upgrade policies >= 3 ---" -ForegroundColor Cyan
try {
    Import-Module "$RepoRoot\PSSymantecSEPM\PSSymantecSEPM.psm1" -Force
    & (Get-Module PSSymantecSEPM) { $script:SkipCert = $true }
    $s = Initialize-SEPMSession
    $summary = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/upgrade" -Headers $s.Headers -SkipCert:$s.SkipCert
    $content = Get-SummaryContent $summary
    $count = if ($content) { $content.Count } else { 0 }
    if ($count -lt 3) { throw "FAIL: expected >= 3, got $count" }
    Write-Host "  VERDICT: PASS (count=$count)"
    $passCount++
} catch {
    Write-Host "  VERDICT: FAIL ($($_.Exception.Message))" -ForegroundColor Red
    $failCount++
}

# ── A7: TDAD policies >= 2 ──
Write-Host "--- A7 : TDAD policies >= 2 ---" -ForegroundColor Cyan
try {
    Import-Module "$RepoRoot\PSSymantecSEPM\PSSymantecSEPM.psm1" -Force
    & (Get-Module PSSymantecSEPM) { $script:SkipCert = $true }
    $s = Initialize-SEPMSession
    $summary = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/tdad" -Headers $s.Headers -SkipCert:$s.SkipCert
    $content = Get-SummaryContent $summary
    $count = if ($content) { $content.Count } else { 0 }
    if ($count -lt 2) { throw "FAIL: expected >= 2, got $count" }
    Write-Host "  VERDICT: PASS (count=$count)"
    $passCount++
} catch {
    Write-Host "  VERDICT: FAIL ($($_.Exception.Message))" -ForegroundColor Red
    $failCount++
}

# ── A8: Host Groups >= 2 ──
Write-Host "--- A8 : Host Groups >= 2 ---" -ForegroundColor Cyan
try {
    Import-Module "$RepoRoot\PSSymantecSEPM\PSSymantecSEPM.psm1" -Force
    & (Get-Module PSSymantecSEPM) { $script:SkipCert = $true }
    $s = Initialize-SEPMSession
    $summary = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/policy-objects/hostgroups/summary" -Headers $s.Headers -SkipCert:$s.SkipCert
    $content = Get-SummaryContent $summary
    $count = if ($content) { $content.Count } else { 0 }
    if ($count -lt 2) { throw "FAIL: expected >= 2, got $count" }
    Write-Host "  VERDICT: PASS (count=$count)"
    $passCount++
} catch {
    Write-Host "  VERDICT: FAIL ($($_.Exception.Message))" -ForegroundColor Red
    $failCount++
}

# ── A9: Fingerprint lists >= 2 ──
Write-Host "--- A9 : Fingerprint lists >= 2 ---" -ForegroundColor Cyan
try {
    Import-Module "$RepoRoot\PSSymantecSEPM\PSSymantecSEPM.psm1" -Force
    & (Get-Module PSSymantecSEPM) { $script:SkipCert = $true }
    $seedNames = @('Known Malware Hashes', 'Approved Binaries')
    $found = 0
    foreach ($name in $seedNames) {
        try {
            $fp = Get-SEPMFileFingerprintList -FingerprintListName $name -ErrorAction SilentlyContinue
            if ($fp) {
                $fpName = if ($fp -is [hashtable]) { $fp['name'] } else { $fp.name }
                if ($fpName) { $found++ }
            }
        } catch { }
    }
    if ($found -lt 2) { throw "FAIL: expected >= 2, found $found" }
    Write-Host "  VERDICT: PASS (found $found/2 lists)"
    $passCount++
} catch {
    Write-Host "  VERDICT: FAIL ($($_.Exception.Message))" -ForegroundColor Red
    $failCount++
}

# ── A10: Policies assigned to groups >= 10 ──
Write-Host "--- A10 : Policies assigned to groups >= 10 ---" -ForegroundColor Cyan
try {
    Import-Module "$RepoRoot\PSSymantecSEPM\PSSymantecSEPM.psm1" -Force
    & (Get-Module PSSymantecSEPM) { $script:SkipCert = $true }
    $policies = Get-SEPMPoliciesSummary
    $assigned = 0
    foreach ($p in $policies) {
        $locations = if ($p -is [hashtable]) { $p['assignedtolocations'] } else { $p.assignedtolocations }
        if ($locations) {
            $locCount = if ($locations -is [array]) { $locations.Count } else { 1 }
            $assigned += $locCount
        }
    }
    if ($assigned -lt 10) { throw "FAIL: expected >= 10, got $assigned" }
    Write-Host "  VERDICT: PASS (assignments=$assigned)"
    $passCount++
} catch {
    Write-Host "  VERDICT: FAIL ($($_.Exception.Message))" -ForegroundColor Red
    $failCount++
}

# ── Summary ──
Write-Host ""
Write-Host "=== Results ==="
$total = 10
Write-Host "PASS: $passCount / $total  FAIL: $failCount"

if ($failCount -gt 0) {
    Write-Host "`n=== Smoke: Seed-Validation (PS5.1) — FAILURES DETECTED ==="
    exit 1
}

Write-Host "`n=== Smoke: Seed-Validation (PS5.1) — ALL PASS ==="
