# Smoke verification for TDADPolicies seed (PS7)
# Usage: pwsh -NoProfile -File Scripts/Smoke/Seed-TDADPolicies/batch.ps7.ps1

$ErrorActionPreference = "Continue"

$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"

Write-Host "=== Smoke: Seed TDADPolicies (PS7) ==="

$seedScript = Join-Path -Path $RepoRoot -ChildPath 'Scripts/Seed-SEPMData.ps1'
$seedNames = @('TDAD Enabled', 'TDAD Disabled')

# Helper: normalize content from summary response (handles ConvertTo-Hashtable
# collapsing 1-element arrays into single objects)
function Get-SummaryContent($response) {
    $content = if ($response.ContainsKey('content')) { $response.content } else { $response }
    if ($content -is [hashtable] -and $content.ContainsKey('id')) {
        # Single policy object (1-element array collapsed)
        return @($content)
    }
    return $content
}

# ── Clean state: delete existing seed policies if any ──
$s = Initialize-SEPMSession
$summary = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/tdad" -Headers $s.Headers -SkipCert:$s.SkipCert
$content = Get-SummaryContent $summary
if ($content) {
    foreach ($p in $content) {
        if ($p.name -in $seedNames) {
            $disableBody = @{ name = $p.name; enabled = $false } | ConvertTo-Json
            Invoke-SepmApi -Method PATCH -Uri "$($s.BaseURLv1)/policies/tdad/$($p.id)" -Headers $s.Headers -SkipCert:$s.SkipCert -Body $disableBody
            Invoke-SepmApi -Method DELETE -Uri "$($s.BaseURLv1)/policies/tdad/$($p.id)" -Headers $s.Headers -SkipCert:$s.SkipCert
        }
    }
}

# ── Baseline after cleanup ──
$s = Initialize-SEPMSession
$beforeSummary = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/tdad" -Headers $s.Headers -SkipCert:$s.SkipCert
$beforeCount = if ($beforeSummary -and $beforeSummary.ContainsKey('totalElements')) { $beforeSummary.totalElements } else { 0 }
Write-Host "Before: $beforeCount TDAD policies"

# ── Seed ──
Write-Host "--- Seeding TDADPolicies ---"
$result = & $seedScript -Categories TDADPolicies 6>&1

$outputText = if ($result -is [array]) { $result -join "`n" } else { $result.ToString() }
if ($outputText -notmatch 'TDAD policies seeded: 2') {
    throw "FAIL: expected 'TDAD policies seeded: 2', got: $outputText"
}

# Rebuild module output (seed script may have used -Force import)
Import-Module "$RepoRoot/Output/PSSymantecSEPM/PSSymantecSEPM.psm1" -Force
& (Get-Module PSSymantecSEPM) { $script:SkipCert = $true }

# ── Verify count +2 ──
$s = Initialize-SEPMSession
$afterSummary = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/tdad" -Headers $s.Headers -SkipCert:$s.SkipCert
$afterCount = if ($afterSummary -and $afterSummary.ContainsKey('totalElements')) { $afterSummary.totalElements } else { 0 }
Write-Host "After: $afterCount TDAD policies"
if ($afterCount -ne ($beforeCount + 2)) {
    throw "FAIL: expected $($beforeCount + 2) policies, got $afterCount"
}

# ── Verify policy names ──
$afterContent = Get-SummaryContent $afterSummary
$policyNames = if ($afterContent) { $afterContent.name } else { @() }
$seedNames | ForEach-Object {
    if ($_ -notin $policyNames) { throw "FAIL: policy '$_' not found" }
}
Write-Host "  Both policy names present"

# Helper: get full policy by name
function Get-TDADPolicyByName($name) {
    $s = Initialize-SEPMSession
    $sum = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/tdad" -Headers $s.Headers -SkipCert:$s.SkipCert
    $c = Get-SummaryContent $sum
    $match = $c | Where-Object { $_.name -eq $name } | Select-Object -First 1
    if (-not $match) { return $null }
    return Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/tdad/$($match.id)" -Headers $s.Headers -SkipCert:$s.SkipCert
}

# ── Verify TDAD Enabled config ──
Write-Host "--- Verify TDAD Enabled ---"
$enabled = Get-TDADPolicyByName 'TDAD Enabled'
if (-not $enabled) { throw "FAIL: TDAD Enabled not found" }
if ($enabled.enabled -ne $true) { throw "FAIL: TDAD Enabled.enabled should be true, got: $($enabled.enabled)" }
if ($enabled.configuration.enabled -ne $true) { throw "FAIL: TDAD Enabled configuration.enabled should be true, got: $($enabled.configuration.enabled)" }
if ($enabled.configuration.ad_domains.Count -ne 0) { throw "FAIL: TDAD Enabled ad_domains should be empty, got: $($enabled.configuration.ad_domains.Count)" }
Write-Host "  TDAD Enabled: enabled=true cfg.enabled=true ad_domains=[] - PASS"

# ── Verify TDAD Disabled config ──
Write-Host "--- Verify TDAD Disabled ---"
$disabled = Get-TDADPolicyByName 'TDAD Disabled'
if (-not $disabled) { throw "FAIL: TDAD Disabled not found" }
if ($disabled.enabled -ne $false) { throw "FAIL: TDAD Disabled.enabled should be false, got: $($disabled.enabled)" }
if ($disabled.configuration.enabled -ne $false) { throw "FAIL: TDAD Disabled configuration.enabled should be false, got: $($disabled.configuration.enabled)" }
if ($disabled.configuration.ad_domains.Count -ne 0) { throw "FAIL: TDAD Disabled ad_domains should be empty, got: $($disabled.configuration.ad_domains.Count)" }
Write-Host "  TDAD Disabled: enabled=false cfg.enabled=false ad_domains=[] - PASS"

# ── Idempotency ──
Write-Host "--- Idempotency ---"
$s = Initialize-SEPMSession
$idemSummary = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/tdad" -Headers $s.Headers -SkipCert:$s.SkipCert
$idemBefore = if ($idemSummary -and $idemSummary.ContainsKey('totalElements')) { $idemSummary.totalElements } else { 0 }
$result = & $seedScript -Categories TDADPolicies 6>&1
Import-Module "$RepoRoot/Output/PSSymantecSEPM/PSSymantecSEPM.psm1" -Force
& (Get-Module PSSymantecSEPM) { $script:SkipCert = $true }
$s = Initialize-SEPMSession
$idemSummary2 = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/tdad" -Headers $s.Headers -SkipCert:$s.SkipCert
$idemAfter = if ($idemSummary2 -and $idemSummary2.ContainsKey('totalElements')) { $idemSummary2.totalElements } else { 0 }
if ($idemAfter -ne $idemBefore) { throw "FAIL: count changed ($idemBefore -> $idemAfter)" }
Write-Host "  Idempotent: $idemAfter policies - PASS"

Write-Host "`n=== Smoke: Seed TDADPolicies (PS7) — ALL PASS ===" -ForegroundColor Green
