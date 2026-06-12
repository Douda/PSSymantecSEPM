<#
.SYNOPSIS
    Shared smoke tests for Seed-UpgradePolicies.

.DESCRIPTION
    Dot-sourced by run.ps7.ps1 and run.ps51.ps1 after Common.ps1.
    Cleans old upgrade policies, seeds 3 policies, verifies config details,
    and tests idempotency.
#>

Write-Host "=== Smoke: Seed UpgradePolicies ==="

$seedScript = Join-Path -Path $RepoRoot -ChildPath 'Scripts/Seed-SEPMData.ps1'
$seedNames = @('Zero-Day Upgrade', 'Weekend Upgrade', 'Manual Upgrade')

# ── Clean state: delete existing seed policies if any ──
$s = Initialize-SEPMSession
$summary = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/upgrade" -Headers $s.Headers -SkipCert:$s.SkipCert
$content = if ($summary.ContainsKey('content')) { $summary.content } else { $summary }
if ($content) {
    foreach ($p in $content) {
        if ($p.name -in $seedNames) {
            $disableBody = @{ name = $p.name; enabled = $false } | ConvertTo-Json
            Invoke-SepmApi -Method PATCH -Uri "$($s.BaseURLv1)/policies/upgrade/$($p.id)" -Headers $s.Headers -SkipCert:$s.SkipCert -Body $disableBody
            Invoke-SepmApi -Method DELETE -Uri "$($s.BaseURLv1)/policies/upgrade/$($p.id)" -Headers $s.Headers -SkipCert:$s.SkipCert
        }
    }
}

# Helper: get full policy by name
function Get-UpgradePolicyByName($name) {
    $s = Initialize-SEPMSession
    $sum = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/upgrade" -Headers $s.Headers -SkipCert:$s.SkipCert
    $c = if ($sum.ContainsKey('content')) { $sum.content } else { $sum }
    $match = $c | Where-Object { $_.name -eq $name } | Select-Object -First 1
    if (-not $match) { return $null }
    return Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/upgrade/$($match.id)" -Headers $s.Headers -SkipCert:$s.SkipCert
}

$results = @{}

# ── A1: Baseline count (before seed) ──
$results.A1 = & {
    try {
        $s = Initialize-SEPMSession
        $beforeSummary = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/upgrade" -Headers $s.Headers -SkipCert:$s.SkipCert
        $beforeContent = if ($beforeSummary.ContainsKey('content')) { $beforeSummary.content } else { $beforeSummary }
        $beforeCount = if ($beforeContent) { $beforeContent.Count } else { 0 }
        Write-Host "  Before: $beforeCount Upgrade policies"
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── A2: Seed output ──
$results.A2 = & {
    try {
        $result = & $seedScript -Categories UpgradePolicies 6>&1
        $outputText = if ($result -is [array]) { $result -join "`n" } else { $result.ToString() }
        if ($outputText -notmatch 'Upgrade policies seeded: 3') {
            throw "expected 'Upgrade policies seeded: 3', got: $outputText"
        }
        Write-Host "  VERDICT: PASS" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── A3: Count +3 ──
$results.A3 = & {
    try {
        $s = Initialize-SEPMSession
        $afterSummary = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/upgrade" -Headers $s.Headers -SkipCert:$s.SkipCert
        $afterContent = if ($afterSummary.ContainsKey('content')) { $afterSummary.content } else { $afterSummary }
        $afterCount = if ($afterContent) { $afterContent.Count } else { 0 }
        Write-Host "  After: $afterCount Upgrade policies"
        if ($afterCount -ne ($beforeCount + 3)) {
            throw "expected $($beforeCount + 3) policies, got $afterCount"
        }
        Write-Host "  VERDICT: PASS" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── A4: All 3 policy names present ──
$results.A4 = & {
    try {
        $s = Initialize-SEPMSession
        $afterSummary = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/upgrade" -Headers $s.Headers -SkipCert:$s.SkipCert
        $afterContent = if ($afterSummary.ContainsKey('content')) { $afterSummary.content } else { $afterSummary }
        $policyNames = if ($afterContent) { $afterContent.name } else { @() }
        foreach ($n in $seedNames) {
            if ($n -notin $policyNames) { throw "policy '$n' not found" }
        }
        Write-Host "  All 3 policy names present - PASS" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── A5: Verify Zero-Day Upgrade config ──
$results.A5 = & {
    try {
        Write-Host "--- Verify Zero-Day Upgrade ---"
        $zd = Get-UpgradePolicyByName 'Zero-Day Upgrade'
        if (-not $zd) { throw "Zero-Day Upgrade not found" }
        if ($zd.enabled -ne $true) { throw "Zero-Day enabled should be true, got: $($zd.enabled)" }
        if ($zd.configuration.release_delay_days -ne 0) { throw "Zero-Day release_delay_days should be 0, got: $($zd.configuration.release_delay_days)" }
        if ($zd.configuration.schedule.retry_enabled -ne $true) { throw "Zero-Day retry_enabled should be true" }
        if ($zd.configuration.schedule.time_window -ne 86400) { throw "Zero-Day time_window should be 86400, got: $($zd.configuration.schedule.time_window)" }
        $daily = $zd.configuration.schedule.daily
        if ($daily.monday -ne $true -or $daily.tuesday -ne $true -or $daily.wednesday -ne $true -or
            $daily.thursday -ne $true -or $daily.friday -ne $true -or $daily.saturday -ne $true -or $daily.sunday -ne $true) {
            throw "Zero-Day should have all 7 days enabled"
        }
        Write-Host "  Zero-Day: delay=0 all_days=true retry=true window=86400 - PASS" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── A6: Verify Weekend Upgrade config ──
$results.A6 = & {
    try {
        Write-Host "--- Verify Weekend Upgrade ---"
        $we = Get-UpgradePolicyByName 'Weekend Upgrade'
        if (-not $we) { throw "Weekend Upgrade not found" }
        if ($we.enabled -ne $true) { throw "Weekend enabled should be true, got: $($we.enabled)" }
        if ($we.configuration.release_delay_days -ne 7) { throw "Weekend release_delay_days should be 7, got: $($we.configuration.release_delay_days)" }
        if ($we.configuration.schedule.retry_enabled -ne $true) { throw "Weekend retry_enabled should be true" }
        if ($we.configuration.schedule.time_window -ne 14400) { throw "Weekend time_window should be 14400, got: $($we.configuration.schedule.time_window)" }
        $wdaily = $we.configuration.schedule.daily
        if ($wdaily.saturday -ne $true -or $wdaily.sunday -ne $true) {
            throw "Weekend should have Saturday+Sunday enabled"
        }
        if ($wdaily.monday -ne $false -or $wdaily.tuesday -ne $false -or $wdaily.wednesday -ne $false -or
            $wdaily.thursday -ne $false -or $wdaily.friday -ne $false) {
            throw "Weekend should have weekdays disabled"
        }
        Write-Host "  Weekend: delay=7 sat+sun=true retry=true window=14400 - PASS" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── A7: Verify Manual Upgrade config ──
$results.A7 = & {
    try {
        Write-Host "--- Verify Manual Upgrade ---"
        $mu = Get-UpgradePolicyByName 'Manual Upgrade'
        if (-not $mu) { throw "Manual Upgrade not found" }
        if ($mu.enabled -ne $false) { throw "Manual enabled should be false, got: $($mu.enabled)" }
        Write-Host "  Manual: enabled=$($mu.enabled) - PASS" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── A8: Idempotency ──
$results.A8 = & {
    try {
        Write-Host "--- Idempotency ---"
        $s = Initialize-SEPMSession
        $idemSummary = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/upgrade" -Headers $s.Headers -SkipCert:$s.SkipCert
        $idemContent = if ($idemSummary.ContainsKey('content')) { $idemSummary.content } else { $idemSummary }
        $idemBefore = if ($idemContent) { $idemContent.Count } else { 0 }
        $result = & $seedScript -Categories UpgradePolicies 6>&1
        $s = Initialize-SEPMSession
        $idemSummary2 = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/upgrade" -Headers $s.Headers -SkipCert:$s.SkipCert
        $idemContent2 = if ($idemSummary2.ContainsKey('content')) { $idemSummary2.content } else { $idemSummary2 }
        $idemAfter = if ($idemContent2) { $idemContent2.Count } else { 0 }
        if ($idemAfter -ne $idemBefore) { throw "count changed ($idemBefore -> $idemAfter)" }
        Write-Host "  Idempotent: $idemAfter policies - PASS" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── Summary ──
Write-Summary -Results $results -Label "Seed UpgradePolicies Smoke Tests"
