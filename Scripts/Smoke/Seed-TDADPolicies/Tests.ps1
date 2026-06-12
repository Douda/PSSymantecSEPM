<#
.SYNOPSIS
    Shared smoke tests for Seed-TDADPolicies.

.DESCRIPTION
    Dot-sourced by run.ps7.ps1 and run.ps51.ps1 after Common.ps1.
    Cleans old TDAD policies, seeds 2 policies, verifies config details,
    and tests idempotency.
#>

Write-Host "=== Smoke: Seed TDADPolicies ==="

# ── Private function wrappers (module-scope tunnel) ──
$script:__SepmModule = Get-Module PSSymantecSEPM

function Invoke-SepmApi {
    & $script:__SepmModule { Invoke-SepmApi @args } @args
}
function Initialize-SEPMSession {
    & $script:__SepmModule { Initialize-SEPMSession @args } @args
}

$seedScript = Join-Path -Path $RepoRoot -ChildPath 'Scripts/Seed-SEPMData.ps1'
$seedNames = @('TDAD Enabled', 'TDAD Disabled')

# Helper: normalize content from summary response (handles ConvertTo-Hashtable
# collapsing 1-element arrays into single objects)
function Get-SummaryContent($response) {
    $content = if ($response.ContainsKey('content')) { $response.content } else { $response }
    if ($content -is [hashtable] -and $content.ContainsKey('id')) {
        return @($content)
    }
    return $content
}

# Helper: get full policy by name
function Get-TDADPolicyByName($name) {
    $s = Initialize-SEPMSession
    $sum = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/tdad" -Headers $s.Headers -SkipCert:$s.SkipCert
    $c = Get-SummaryContent $sum
    $match = $c | Where-Object { $_.name -eq $name } | Select-Object -First 1
    if (-not $match) { return $null }
    return Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/tdad/$($match.id)" -Headers $s.Headers -SkipCert:$s.SkipCert
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

$results = @{}

# ── A1: Baseline count (before seed) ──
$results.A1 = & {
    try {
        $s = Initialize-SEPMSession
        $beforeSummary = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/tdad" -Headers $s.Headers -SkipCert:$s.SkipCert
        $script:beforeCount = if ($beforeSummary -and $beforeSummary.ContainsKey('totalElements')) { $beforeSummary.totalElements } else { 0 }
        Write-Host "  Before: $beforeCount TDAD policies"
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── A2: Seed output ──
$results.A2 = & {
    try {
        $result = & $seedScript -Categories TDADPolicies 6>&1
        $outputText = if ($result -is [array]) { $result -join "`n" } else { $result.ToString() }
        if ($outputText -notmatch 'TDAD policies seeded: 2') {
            throw "expected 'TDAD policies seeded: 2', got: $outputText"
        }
        Write-Host "  VERDICT: PASS" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── A3: Count +2 ──
$results.A3 = & {
    try {
        $s = Initialize-SEPMSession
        $afterSummary = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/tdad" -Headers $s.Headers -SkipCert:$s.SkipCert
        $afterCount = if ($afterSummary -and $afterSummary.ContainsKey('totalElements')) { $afterSummary.totalElements } else { 0 }
        Write-Host "  After: $afterCount TDAD policies"
        if ($afterCount -ne ($beforeCount + 2)) {
            throw "expected $($beforeCount + 2) policies, got $afterCount"
        }
        Write-Host "  VERDICT: PASS" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── A4: Both policy names present ──
$results.A4 = & {
    try {
        $s = Initialize-SEPMSession
        $afterSummary = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/tdad" -Headers $s.Headers -SkipCert:$s.SkipCert
        $afterContent = Get-SummaryContent $afterSummary
        $policyNames = if ($afterContent) { $afterContent.name } else { @() }
        foreach ($n in $seedNames) {
            if ($n -notin $policyNames) { throw "policy '$n' not found" }
        }
        Write-Host "  Both policy names present - PASS" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── A5: Verify TDAD Enabled config ──
$results.A5 = & {
    try {
        Write-Host "--- Verify TDAD Enabled ---"
        $enabled = Get-TDADPolicyByName 'TDAD Enabled'
        if (-not $enabled) { throw "TDAD Enabled not found" }
        if ($enabled.enabled -ne $true) { throw "TDAD Enabled.enabled should be true, got: $($enabled.enabled)" }
        if ($enabled.configuration.enabled -ne $true) { throw "TDAD Enabled configuration.enabled should be true, got: $($enabled.configuration.enabled)" }
        if ($enabled.configuration.ad_domains.Count -ne 0) { throw "TDAD Enabled ad_domains should be empty, got: $($enabled.configuration.ad_domains.Count)" }
        Write-Host "  TDAD Enabled: enabled=true cfg.enabled=true ad_domains=[] - PASS" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── A6: Verify TDAD Disabled config ──
$results.A6 = & {
    try {
        Write-Host "--- Verify TDAD Disabled ---"
        $disabled = Get-TDADPolicyByName 'TDAD Disabled'
        if (-not $disabled) { throw "TDAD Disabled not found" }
        if ($disabled.enabled -ne $false) { throw "TDAD Disabled.enabled should be false, got: $($disabled.enabled)" }
        if ($disabled.configuration.enabled -ne $false) { throw "TDAD Disabled configuration.enabled should be false, got: $($disabled.configuration.enabled)" }
        if ($disabled.configuration.ad_domains.Count -ne 0) { throw "TDAD Disabled ad_domains should be empty, got: $($disabled.configuration.ad_domains.Count)" }
        Write-Host "  TDAD Disabled: enabled=false cfg.enabled=false ad_domains=[] - PASS" -ForegroundColor Green
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
        $idemSummary = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/tdad" -Headers $s.Headers -SkipCert:$s.SkipCert
        $idemBefore = if ($idemSummary -and $idemSummary.ContainsKey('totalElements')) { $idemSummary.totalElements } else { 0 }
        $result = & $seedScript -Categories TDADPolicies 6>&1
        $s = Initialize-SEPMSession
        $idemSummary2 = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/tdad" -Headers $s.Headers -SkipCert:$s.SkipCert
        $idemAfter = if ($idemSummary2 -and $idemSummary2.ContainsKey('totalElements')) { $idemSummary2.totalElements } else { 0 }
        if ($idemAfter -ne $idemBefore) { throw "count changed ($idemBefore -> $idemAfter)" }
        Write-Host "  Idempotent: $idemAfter policies - PASS" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── Summary ──
Write-Summary -Results $results -Label "Seed TDADPolicies Smoke Tests"
