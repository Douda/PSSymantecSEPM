# Smoke verification for TDADPolicies seed (PS5.1)
# Run via: python3 Scripts/invoke-winrm.py 'C:\Users\smokeuser\Desktop\Shared\smoke-tdad.ps1'

$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"
. "$RepoRoot\Common-PS51.ps1"

Write-Host "=== Smoke: Seed TDADPolicies (PS5.1) ==="

$seedScript = Join-Path -Path $RepoRoot -ChildPath 'Seed-SEPMData.ps1'

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
$session = & (Get-Module PSSymantecSEPM) { Initialize-SEPMSession }
$summary = Invoke-SepmApi -Method GET -Uri "$($session.BaseURLv1)/policies/summary/tdad" -Session $session
$seedNames = @('TDAD Enabled', 'TDAD Disabled')
$content = Get-SummaryContent $summary
if ($content) {
    foreach ($p in $content) {
        if ($p.name -in $seedNames) {
            $disableBody = @{ name = $p.name; enabled = $false } | ConvertTo-Json
            Invoke-SepmApi -Method PATCH -Uri "$($session.BaseURLv1)/policies/tdad/$($p.id)" -Session $session -Body $disableBody
            Invoke-SepmApi -Method DELETE -Uri "$($session.BaseURLv1)/policies/tdad/$($p.id)" -Session $session
        }
    }
}

# ── Baseline after cleanup ──
$beforeSummary = Invoke-SepmApi -Method GET -Uri "$($session.BaseURLv1)/policies/summary/tdad" -Session $session
$beforeCount = if ($beforeSummary -and $beforeSummary.ContainsKey('totalElements')) { $beforeSummary.totalElements } else { 0 }
Write-Host "Before: $beforeCount TDAD policies"

# ── Seed ──
Write-Host "--- Seeding TDADPolicies ---"
$result = & $seedScript -Categories TDADPolicies 6>&1

$outputText = if ($null -eq $result) { '' } elseif ($result -is [array]) { $result -join "`n" } else { $result.ToString() }
if ($outputText -notmatch 'TDAD policies seeded: 2') {
    throw "FAIL: expected 'TDAD policies seeded: 2', got: $outputText"
}

# Refresh session after orchestrator reimported the module
$session = & (Get-Module PSSymantecSEPM) { Initialize-SEPMSession }

# ── Verify count +2 ──
$afterSummary = Invoke-SepmApi -Method GET -Uri "$($session.BaseURLv1)/policies/summary/tdad" -Session $session
$afterCount = if ($afterSummary -and $afterSummary.ContainsKey('totalElements')) { $afterSummary.totalElements } else { 0 }
Write-Host "After: $afterCount TDAD policies"
if ($afterCount -ne ($beforeCount + 2)) {
    throw "FAIL: expected $($beforeCount + 2) policies, got $afterCount"
}

# ── Verify policy names ──
$afterContent = Get-SummaryContent $afterSummary
$policyNames = if ($afterContent) { $afterContent.name } else { @() }
foreach ($n in $seedNames) {
    if ($n -notin $policyNames) { throw "FAIL: policy '$n' not found" }
}
Write-Host "  Both policy names present"

# Helper: get full policy by name
function Get-TDADPolicyByName($name) {
    $s = & (Get-Module PSSymantecSEPM) { Initialize-SEPMSession }
    $sum = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/tdad" -Session $s
    $c = Get-SummaryContent $sum
    $match = $c | Where-Object { $_.name -eq $name } | Select-Object -First 1
    if (-not $match) { return $null }
    $full = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/tdad/$($match.id)" -Session $s
    return $full
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
$sess2 = & (Get-Module PSSymantecSEPM) { Initialize-SEPMSession }
$sumIdem = Invoke-SepmApi -Method GET -Uri "$($sess2.BaseURLv1)/policies/summary/tdad" -Session $sess2
$idemBefore = if ($sumIdem -and $sumIdem.ContainsKey('totalElements')) { $sumIdem.totalElements } else { 0 }
$result = & $seedScript -Categories TDADPolicies 6>&1
$sumIdem2 = Invoke-SepmApi -Method GET -Uri "$($sess2.BaseURLv1)/policies/summary/tdad" -Session $sess2
$idemAfter = if ($sumIdem2 -and $sumIdem2.ContainsKey('totalElements')) { $sumIdem2.totalElements } else { 0 }
if ($idemAfter -ne $idemBefore) { throw "FAIL: count changed ($idemBefore -> $idemAfter)" }
Write-Host "  Idempotent: $idemAfter policies - PASS"

Write-Host "`n=== Smoke: Seed TDADPolicies (PS5.1) — ALL PASS ===" -ForegroundColor Green
