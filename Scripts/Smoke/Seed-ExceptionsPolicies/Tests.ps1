<#
.SYNOPSIS
    Shared smoke tests for Seed-ExceptionsPolicies.

.DESCRIPTION
    Dot-sourced by run.ps7.ps1 and run.ps51.ps1 after Common.ps1.
    Cleans old seed policies, seeds 4 policies, verifies config details,
    and tests idempotency.
#>

Write-Host "=== Smoke: Seed ExceptionsPolicies ==="

$seedScript = Join-Path -Path $RepoRoot -ChildPath 'Scripts/Seed-SEPMData.ps1'
$seedNames = @('Standard Workstation Exceptions', 'Server Exceptions', 'Developer Exceptions', 'Emergency Disabled')

# ── Clean state: delete existing seed policies if any ──
$s = Initialize-SEPMSession
$summary = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/exceptions" -Headers $s.Headers -SkipCert:$s.SkipCert
$content = if ($summary.ContainsKey('content')) { $summary.content } else { $summary }
if ($content) {
    foreach ($p in $content) {
        if ($p.name -in $seedNames) {
            $disableBody = @{ name = $p.name; enabled = $false } | ConvertTo-Json
            Invoke-SepmApi -Method PATCH -Uri "$($s.BaseURLv1)/policies/exceptions/$($p.id)" -Headers $s.Headers -SkipCert:$s.SkipCert -Body $disableBody
            Invoke-SepmApi -Method DELETE -Uri "$($s.BaseURLv1)/policies/exceptions/$($p.id)" -Headers $s.Headers -SkipCert:$s.SkipCert
        }
    }
}

$results = @{}

# ── A1: Baseline count (before seed) ──
$results.A1 = & {
    try {
        $script:beforeCount = @(Get-SEPMPoliciesSummary | Where-Object { $_.policytype -eq 'exceptions' }).Count
        Write-Host "  Before: $beforeCount exceptions policies"
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── A2: Seed output ──
$results.A2 = & {
    try {
        $result = & $seedScript -Categories ExceptionsPolicies 6>&1
        $outputText = if ($result -is [array]) { $result -join "`n" } else { $result.ToString() }
        if ($outputText -notmatch 'Exceptions policies seeded: 4') {
            throw "expected 'Exceptions policies seeded: 4', got: $outputText"
        }
        Write-Host "  VERDICT: PASS" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── A3: Count +4 ──
$results.A3 = & {
    try {
        $afterCount = @(Get-SEPMPoliciesSummary | Where-Object { $_.policytype -eq 'exceptions' }).Count
        Write-Host "  After: $afterCount exceptions policies"
        if ($afterCount -ne ($beforeCount + 4)) {
            throw "expected $($beforeCount + 4) policies, got $afterCount"
        }
        Write-Host "  VERDICT: PASS" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── A4: All 4 policy names present ──
$results.A4 = & {
    try {
        $exceptionsSummary = Get-SEPMPoliciesSummary | Where-Object { $_.policytype -eq 'exceptions' }
        $policyNames = $exceptionsSummary.name
        foreach ($n in $seedNames) {
            if ($n -notin $policyNames) { throw "policy '$n' not found" }
        }
        Write-Host "  All 4 policy names present - PASS" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── A5: Verify Standard Workstation config ──
$results.A5 = & {
    try {
        Write-Host "--- Verify Standard Workstation config ---"
        $stdPolicy = Get-SEPMExceptionPolicy -PolicyName 'Standard Workstation Exceptions'
        if (-not $stdPolicy) { throw "Get-SEPMExceptionPolicy returned null" }
        if ($stdPolicy.enabled -ne $true) { throw "Standard Workstation should be enabled" }
        $files = Get-SEPMExceptionPolicy -PolicyName 'Standard Workstation Exceptions' -List files
        $dirs = Get-SEPMExceptionPolicy -PolicyName 'Standard Workstation Exceptions' -List directories
        $exts = Get-SEPMExceptionPolicy -PolicyName 'Standard Workstation Exceptions' -List extensions
        if ($files.Count -lt 3) { throw "expected >= 3 files, got $($files.Count)" }
        if ($dirs.Count -lt 2) { throw "expected >= 2 dirs, got $($dirs.Count)" }
        if ($exts.Count -lt 1) { throw "expected >= 1 extension, got $($exts.Count)" }
        Write-Host "  Standard: $($files.Count) files, $($dirs.Count) dirs, $($exts.Count) exts - PASS" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── A6: Verify Server Exceptions (tamper only) ──
$results.A6 = & {
    try {
        Write-Host "--- Verify Server Exceptions config ---"
        $srvPolicy = Get-SEPMExceptionPolicy -PolicyName 'Server Exceptions'
        if ($srvPolicy.enabled -ne $true) { throw "Server should be enabled" }
        $srvTamper = Get-SEPMExceptionPolicy -PolicyName 'Server Exceptions' -List tamper
        if ($srvTamper.Count -lt 1) { throw "Server should have tamper rules" }
        Write-Host "  Server: $($srvTamper.Count) tamper rules - PASS" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── A7: Verify Developer Exceptions ──
$results.A7 = & {
    try {
        Write-Host "--- Verify Developer Exceptions config ---"
        $devPolicy = Get-SEPMExceptionPolicy -PolicyName 'Developer Exceptions'
        if ($devPolicy.enabled -ne $true) { throw "Developer should be enabled" }
        $devDirs = Get-SEPMExceptionPolicy -PolicyName 'Developer Exceptions' -List directories
        if ($devDirs.Count -lt 2) { throw "Developer should have >= 2 dirs" }
        $allRecursive = ($devDirs | Where-Object { $_.scantype -eq 'All' -and $_.recursive -eq $true }).Count
        if ($allRecursive -lt 2) { throw "Developer should have broad recursive dirs" }
        Write-Host "  Developer: $($devDirs.Count) dirs, $allRecursive broad recursive - PASS" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── A8: Verify Emergency Disabled is disabled ──
$results.A8 = & {
    try {
        Write-Host "--- Verify Emergency Disabled ---"
        $emPolicy = Get-SEPMExceptionPolicy -PolicyName 'Emergency Disabled'
        if ($emPolicy.enabled -ne $false) { throw "Emergency should be disabled" }
        Write-Host "  Emergency: enabled=$($emPolicy.enabled) - PASS" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── A9: Idempotency ──
$results.A9 = & {
    try {
        Write-Host "--- Idempotency ---"
        $idemBefore = @(Get-SEPMPoliciesSummary | Where-Object { $_.policytype -eq 'exceptions' }).Count
        $result = & $seedScript -Categories ExceptionsPolicies 6>&1
        $idemAfter = @(Get-SEPMPoliciesSummary | Where-Object { $_.policytype -eq 'exceptions' }).Count
        if ($idemAfter -ne $idemBefore) { throw "count changed ($idemBefore -> $idemAfter)" }
        Write-Host "  Idempotent: $idemAfter policies - PASS" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── Summary ──
Write-Summary -Results $results -Label "Seed ExceptionsPolicies Smoke Tests"
