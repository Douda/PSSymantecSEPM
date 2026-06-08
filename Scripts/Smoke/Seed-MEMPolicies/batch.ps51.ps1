# Smoke verification for MEMPolicies seed (PS5.1)
# Run via: python3 Scripts/invoke-winrm.py 'C:\Users\smokeuser\Desktop\Shared\smoke-mem.ps1'

$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"
. "$RepoRoot\Common-PS51.ps1"

Write-Host "=== Smoke: Seed MEMPolicies (PS5.1) ==="

$seedScript = Join-Path -Path $RepoRoot -ChildPath 'Seed-SEPMData.ps1'

# ── Clean state: delete existing seed policies if any ──
$session = & (Get-Module PSSymantecSEPM) { Initialize-SEPMSession }
$summary = Invoke-SepmApi -Method GET -Uri "$($session.BaseURLv1)/policies/summary/mem" -Session $session
$seedNames = @('Standard MEM', 'Advanced MEM', 'Java-Only MEM', 'Audit MEM')
$content = if ($summary.ContainsKey('content')) { $summary.content } else { $summary }
if ($content) {
    foreach ($p in $content) {
        if ($p.name -in $seedNames) {
            $disableBody = @{ name = $p.name; enabled = $false } | ConvertTo-Json
            Invoke-SepmApi -Method PATCH -Uri "$($session.BaseURLv1)/policies/mem/$($p.id)" -Session $session -Body $disableBody
            Invoke-SepmApi -Method DELETE -Uri "$($session.BaseURLv1)/policies/mem/$($p.id)" -Session $session
        }
    }
}

# ── Baseline after cleanup ──
$beforeSummary = Invoke-SepmApi -Method GET -Uri "$($session.BaseURLv1)/policies/summary/mem" -Session $session
$beforeContent = if ($beforeSummary.ContainsKey('content')) { $beforeSummary.content } else { $beforeSummary }
$beforeCount = if ($beforeContent) { $beforeContent.Count } else { 0 }
Write-Host "Before: $beforeCount MEM policies"

# ── Seed ──
Write-Host "--- Seeding MEMPolicies ---"
$result = & $seedScript -Categories MEMPolicies 6>&1

$outputText = if ($result -is [array]) { $result -join "`n" } else { $result.ToString() }
if ($outputText -notmatch 'MEM policies seeded: 4') {
    throw "FAIL: expected 'MEM policies seeded: 4', got: $outputText"
}

# ── Verify count +4 ──
$afterSummary = Invoke-SepmApi -Method GET -Uri "$($session.BaseURLv1)/policies/summary/mem" -Session $session
$afterContent = if ($afterSummary.ContainsKey('content')) { $afterSummary.content } else { $afterSummary }
$afterCount = if ($afterContent) { $afterContent.Count } else { 0 }
Write-Host "After: $afterCount MEM policies"
if ($afterCount -ne ($beforeCount + 4)) {
    throw "FAIL: expected $($beforeCount + 4) policies, got $afterCount"
}

# ── Verify policy names ──
$policyNames = if ($afterContent) { $afterContent.name } else { @() }
foreach ($n in $seedNames) {
    if ($n -notin $policyNames) { throw "FAIL: policy '$n' not found" }
}
Write-Host "  All 4 policy names present"

# Helper: get full policy by name
function Get-MEMPolicyByName($name) {
    $s = & (Get-Module PSSymantecSEPM) { Initialize-SEPMSession }
    $sum = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/mem" -Session $s
    $c = if ($sum.ContainsKey('content')) { $sum.content } else { $sum }
    $match = $c | Where-Object { $_.name -eq $name } | Select-Object -First 1
    if (-not $match) { return $null }
    $full = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/mem/$($match.id)" -Session $s
    return $full
}

# ── Verify Standard MEM config ──
Write-Host "--- Verify Standard MEM ---"
$std = Get-MEMPolicyByName 'Standard MEM'
if (-not $std) { throw "FAIL: Standard MEM not found" }
if ($std.configuration.enabled -ne $true) { throw "FAIL: Standard MEM config.enabled should be true" }
if ($std.configuration.enablejavaprotection -ne $true) { throw "FAIL: Standard MEM enablejavaprotection should be true" }
if ($std.configuration.enableadvanced -ne $false) { throw "FAIL: Standard MEM enableadvanced should be false" }
Write-Host "  Standard: enabled=$($std.configuration.enabled) java=$($std.configuration.enablejavaprotection) advanced=$($std.configuration.enableadvanced) - PASS"

# ── Verify Advanced MEM ──
Write-Host "--- Verify Advanced MEM ---"
$adv = Get-MEMPolicyByName 'Advanced MEM'
if (-not $adv) { throw "FAIL: Advanced MEM not found" }
if ($adv.configuration.enableadvanced -ne $true) { throw "FAIL: Advanced MEM enableadvanced should be true" }
$customCount = if ($adv.configuration.customrules) { $adv.configuration.customrules.Count } else { 0 }
if ($customCount -lt 2) { throw "FAIL: Advanced MEM customrules should be >= 2, got $customCount" }
$overrideCount = if ($adv.configuration.globaltechniqueoverrides) { $adv.configuration.globaltechniqueoverrides.Count } else { 0 }
if ($overrideCount -lt 1) { throw "FAIL: Advanced MEM globaltechniqueoverrides should be >= 1, got $overrideCount" }
Write-Host "  Advanced: advanced=true customs=$customCount overrides=$overrideCount - PASS"

# ── Verify Java-Only MEM ──
Write-Host "--- Verify Java-Only MEM ---"
$java = Get-MEMPolicyByName 'Java-Only MEM'
if (-not $java) { throw "FAIL: Java-Only MEM not found" }
if ($java.configuration.enabled -ne $false) { throw "FAIL: Java-Only MEM config.enabled should be false, got: $($java.configuration.enabled)" }
if ($java.configuration.enablejavaprotection -ne $true) { throw "FAIL: Java-Only MEM enablejavaprotection should be true" }
if ($java.configuration.enableadvanced -ne $false) { throw "FAIL: Java-Only MEM enableadvanced should be false" }
Write-Host "  Java-Only: enabled=$($java.configuration.enabled) java=$($java.configuration.enablejavaprotection) - PASS"

# ── Verify Audit MEM ──
Write-Host "--- Verify Audit MEM ---"
$audit = Get-MEMPolicyByName 'Audit MEM'
if (-not $audit) { throw "FAIL: Audit MEM not found" }
if ($audit.configuration.globalauditmodeoverride -ne $true) { throw "FAIL: Audit MEM globalauditmodeoverride should be true, got: $($audit.configuration.globalauditmodeoverride)" }
if ($audit.configuration.enabled -ne $true) { throw "FAIL: Audit MEM config.enabled should be true" }
Write-Host "  Audit: enabled=$($audit.configuration.enabled) audit=$($audit.configuration.globalauditmodeoverride) - PASS"

# ── Idempotency ──
Write-Host "--- Idempotency ---"
$sess2 = & (Get-Module PSSymantecSEPM) { Initialize-SEPMSession }
$sumIdem = Invoke-SepmApi -Method GET -Uri "$($sess2.BaseURLv1)/policies/summary/mem" -Session $sess2
$contentIdem = if ($sumIdem.ContainsKey('content')) { $sumIdem.content } else { $sumIdem }
$idemBefore = if ($contentIdem) { $contentIdem.Count } else { 0 }
$result = & $seedScript -Categories MEMPolicies 6>&1
$sumIdem2 = Invoke-SepmApi -Method GET -Uri "$($sess2.BaseURLv1)/policies/summary/mem" -Session $sess2
$contentIdem2 = if ($sumIdem2.ContainsKey('content')) { $sumIdem2.content } else { $sumIdem2 }
$idemAfter = if ($contentIdem2) { $contentIdem2.Count } else { 0 }
if ($idemAfter -ne $idemBefore) { throw "FAIL: count changed ($idemBefore -> $idemAfter)" }
Write-Host "  Idempotent: $idemAfter policies - PASS"

Write-Host "`n=== Smoke: Seed MEMPolicies (PS5.1) — ALL PASS ===" -ForegroundColor Green
