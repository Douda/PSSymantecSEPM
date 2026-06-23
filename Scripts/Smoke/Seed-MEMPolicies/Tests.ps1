<#
.SYNOPSIS
    Shared smoke tests for Seed-MEMPolicies.

.DESCRIPTION
    Dot-sourced by run.ps7.ps1 and run.ps51.ps1 after Common.ps1.
    Cleans old MEM policies, seeds 4 policies, verifies config details,
    and tests idempotency.
#>

Write-Host "=== Smoke: Seed MEMPolicies ==="

# ── Private function wrappers (module-scope tunnel) ──
$script:__SepmModule = Get-Module PSSymantecSEPM

function Invoke-SepmApi {
    & $script:__SepmModule { Invoke-SepmApi @args } @args
}
function Initialize-SEPMSession {
    & $script:__SepmModule { Initialize-SEPMSession @args } @args
}

$seedScript = Join-Path -Path $RepoRoot -ChildPath 'Scripts/Seed-SEPMData.ps1'
$seedNames = @('Standard MEM', 'Advanced MEM', 'Java-Only MEM', 'Audit MEM')

# ── Clean state: delete existing seed policies if any ──
$s = Initialize-SEPMSession
$summary = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/mem" -Headers $s.Headers -SkipCert:$s.SkipCert
$content = if ($summary.ContainsKey('content')) { $summary.content } else { $summary }
if ($content) {
    foreach ($p in $content) {
        if ($p.name -in $seedNames) {
            $disableBody = @{ name = $p.name; enabled = $false } | ConvertTo-Json
            Invoke-SepmApi -Method PATCH -Uri "$($s.BaseURLv1)/policies/mem/$($p.id)" -Headers $s.Headers -SkipCert:$s.SkipCert -Body $disableBody
            Invoke-SepmApi -Method DELETE -Uri "$($s.BaseURLv1)/policies/mem/$($p.id)" -Headers $s.Headers -SkipCert:$s.SkipCert
        }
    }
}

# Helper: get full policy by name
function Get-MEMPolicyByName($name) {
    $s = Initialize-SEPMSession
    $sum = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/mem" -Headers $s.Headers -SkipCert:$s.SkipCert
    $c = if ($sum.ContainsKey('content')) { $sum.content } else { $sum }
    $match = $c | Where-Object { $_.name -eq $name } | Select-Object -First 1
    if (-not $match) { return $null }
    return Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/mem/$($match.id)" -Headers $s.Headers -SkipCert:$s.SkipCert
}

$results = @{}

# ── A1: Baseline count (before seed) ──
$results.A1 = & {
    try {
        $s = Initialize-SEPMSession
        $beforeSummary = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/mem" -Headers $s.Headers -SkipCert:$s.SkipCert
        $beforeContent = if ($beforeSummary.ContainsKey('content')) { $beforeSummary.content } else { $beforeSummary }
        $script:beforeCount = if ($beforeContent) { $beforeContent.Count } else { 0 }
        Write-Host "  Before: $beforeCount MEM policies"
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── A2: Seed output ──
$results.A2 = & {
    try {
        $result = & $seedScript -Categories MEMPolicies 6>&1
        $outputText = if ($result -is [array]) { $result -join "`n" } else { $result.ToString() }
        if ($outputText -notmatch 'MEM policies seeded: 4') {
            throw "expected 'MEM policies seeded: 4', got: $outputText"
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
        $s = Initialize-SEPMSession
        $afterSummary = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/mem" -Headers $s.Headers -SkipCert:$s.SkipCert
        $afterContent = if ($afterSummary.ContainsKey('content')) { $afterSummary.content } else { $afterSummary }
        $afterCount = if ($afterContent) { $afterContent.Count } else { 0 }
        Write-Host "  After: $afterCount MEM policies"
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
        $s = Initialize-SEPMSession
        $afterSummary = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/mem" -Headers $s.Headers -SkipCert:$s.SkipCert
        $afterContent = if ($afterSummary.ContainsKey('content')) { $afterSummary.content } else { $afterSummary }
        $policyNames = if ($afterContent) { $afterContent.name } else { @() }
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

# ── A5: Verify Standard MEM ──
$results.A5 = & {
    try {
        Write-Host "--- Verify Standard MEM ---"
        $std = Get-MEMPolicyByName 'Standard MEM'
        if (-not $std) { throw "Standard MEM not found" }
        if ($std.configuration.enabled -ne $true) { throw "Standard MEM config.enabled should be true" }
        if ($std.configuration.enablejavaprotection -ne $true) { throw "Standard MEM enablejavaprotection should be true" }
        if ($std.configuration.enableadvanced -ne $false) { throw "Standard MEM enableadvanced should be false" }
        Write-Host "  Standard: enabled=$($std.configuration.enabled) java=$($std.configuration.enablejavaprotection) advanced=$($std.configuration.enableadvanced) - PASS" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── A6: Verify Advanced MEM ──
$results.A6 = & {
    try {
        Write-Host "--- Verify Advanced MEM ---"
        $adv = Get-MEMPolicyByName 'Advanced MEM'
        if (-not $adv) { throw "Advanced MEM not found" }
        if ($adv.configuration.enableadvanced -ne $true) { throw "Advanced MEM enableadvanced should be true" }
        $customCount = if ($adv.configuration.customrules) { $adv.configuration.customrules.Count } else { 0 }
        if ($customCount -lt 2) { throw "Advanced MEM customrules should be >= 2, got $customCount" }
        $overrideCount = if ($adv.configuration.globaltechniqueoverrides) { $adv.configuration.globaltechniqueoverrides.Count } else { 0 }
        if ($overrideCount -lt 1) { throw "Advanced MEM globaltechniqueoverrides should be >= 1, got $overrideCount" }
        Write-Host "  Advanced: advanced=true customs=$customCount overrides=$overrideCount - PASS" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── A7: Verify Java-Only MEM ──
$results.A7 = & {
    try {
        Write-Host "--- Verify Java-Only MEM ---"
        $java = Get-MEMPolicyByName 'Java-Only MEM'
        if (-not $java) { throw "Java-Only MEM not found" }
        if ($java.configuration.enabled -ne $false) { throw "Java-Only MEM config.enabled should be false, got: $($java.configuration.enabled)" }
        if ($java.configuration.enablejavaprotection -ne $true) { throw "Java-Only MEM enablejavaprotection should be true" }
        if ($java.configuration.enableadvanced -ne $false) { throw "Java-Only MEM enableadvanced should be false" }
        Write-Host "  Java-Only: enabled=$($java.configuration.enabled) java=$($java.configuration.enablejavaprotection) - PASS" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── A8: Verify Audit MEM ──
$results.A8 = & {
    try {
        Write-Host "--- Verify Audit MEM ---"
        $audit = Get-MEMPolicyByName 'Audit MEM'
        if (-not $audit) { throw "Audit MEM not found" }
        if ($audit.configuration.globalauditmodeoverride -ne $true) { throw "Audit MEM globalauditmodeoverride should be true, got: $($audit.configuration.globalauditmodeoverride)" }
        if ($audit.configuration.enabled -ne $true) { throw "Audit MEM config.enabled should be true" }
        Write-Host "  Audit: enabled=$($audit.configuration.enabled) audit=$($audit.configuration.globalauditmodeoverride) - PASS" -ForegroundColor Green
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
        $s = Initialize-SEPMSession
        $idemSummary = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/mem" -Headers $s.Headers -SkipCert:$s.SkipCert
        $idemContent = if ($idemSummary.ContainsKey('content')) { $idemSummary.content } else { $idemSummary }
        $idemBefore = if ($idemContent) { $idemContent.Count } else { 0 }
        $result = & $seedScript -Categories MEMPolicies 6>&1
        $s = Initialize-SEPMSession
        $idemSummary2 = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/mem" -Headers $s.Headers -SkipCert:$s.SkipCert
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
Write-Summary -Results $results -Label "Seed MEMPolicies Smoke Tests"
