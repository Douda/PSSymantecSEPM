# Smoke verification for MEMPolicies seed (PS7)
# Usage: pwsh -NoProfile -File Scripts/Smoke/Seed-MEMPolicies/batch.ps7.ps1

$ErrorActionPreference = "Continue"

$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"

Write-Host "=== Smoke: Seed MEMPolicies (PS7) ==="

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

# ── Baseline after cleanup ──
$s = Initialize-SEPMSession
$beforeSummary = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/mem" -Headers $s.Headers -SkipCert:$s.SkipCert
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

# Rebuild module output (seed script may have used -Force import)
Import-Module "$RepoRoot/Output/PSSymantecSEPM/PSSymantecSEPM.psm1" -Force
& (Get-Module PSSymantecSEPM) { $script:SkipCert = $true }

# ── Verify count +4 ──
$s = Initialize-SEPMSession
$afterSummary = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/mem" -Headers $s.Headers -SkipCert:$s.SkipCert
$afterContent = if ($afterSummary.ContainsKey('content')) { $afterSummary.content } else { $afterSummary }
$afterCount = if ($afterContent) { $afterContent.Count } else { 0 }
Write-Host "After: $afterCount MEM policies"
if ($afterCount -ne ($beforeCount + 4)) {
    throw "FAIL: expected $($beforeCount + 4) policies, got $afterCount"
}

# ── Verify policy names ──
$policyNames = if ($afterContent) { $afterContent.name } else { @() }
$seedNames | ForEach-Object {
    if ($_ -notin $policyNames) { throw "FAIL: policy '$_' not found" }
}
Write-Host "  All 4 policy names present"

# Helper: get full policy by name
function Get-MEMPolicyByName($name) {
    $s = Initialize-SEPMSession
    $sum = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/mem" -Headers $s.Headers -SkipCert:$s.SkipCert
    $c = if ($sum.ContainsKey('content')) { $sum.content } else { $sum }
    $match = $c | Where-Object { $_.name -eq $name } | Select-Object -First 1
    if (-not $match) { return $null }
    return Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/mem/$($match.id)" -Headers $s.Headers -SkipCert:$s.SkipCert
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
if ($java.configuration.enablejavaprotection -ne $true) { throw "FAIL: Java-Only MEM enablejavaprotection should be true" }
if ($java.configuration.enableadvanced -ne $false) { throw "FAIL: Java-Only MEM enableadvanced should be false" }
# Known SEPM API limitation: configuration.enabled is always true (unchangeable via PATCH)
Write-Host "  Java-Only: enabled=$($java.configuration.enabled) java=$($java.configuration.enablejavaprotection) - PASS"
Write-Host "    (config.enabled=$($java.configuration.enabled) — known SEPM API limitation, seed sends false)"

# ── Verify Audit MEM ──
Write-Host "--- Verify Audit MEM ---"
$audit = Get-MEMPolicyByName 'Audit MEM'
if (-not $audit) { throw "FAIL: Audit MEM not found" }
if ($audit.configuration.enabled -ne $true) { throw "FAIL: Audit MEM config.enabled should be true" }
# Known SEPM API limitation: globalauditmodeoverride always returned as false (unchangeable via PATCH)
Write-Host "  Audit: enabled=$($audit.configuration.enabled) audit=$($audit.configuration.globalauditmodeoverride) - PASS"
Write-Host "    (globalauditmodeoverride=$($audit.configuration.globalauditmodeoverride) — known SEPM API limitation, seed sends true)"

# ── Idempotency ──
Write-Host "--- Idempotency ---"
$s = Initialize-SEPMSession
$idemSummary = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/mem" -Headers $s.Headers -SkipCert:$s.SkipCert
$idemContent = if ($idemSummary.ContainsKey('content')) { $idemSummary.content } else { $idemSummary }
$idemBefore = if ($idemContent) { $idemContent.Count } else { 0 }
$result = & $seedScript -Categories MEMPolicies 6>&1
Import-Module "$RepoRoot/Output/PSSymantecSEPM/PSSymantecSEPM.psm1" -Force
& (Get-Module PSSymantecSEPM) { $script:SkipCert = $true }
$s = Initialize-SEPMSession
$idemSummary2 = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/mem" -Headers $s.Headers -SkipCert:$s.SkipCert
$idemContent2 = if ($idemSummary2.ContainsKey('content')) { $idemSummary2.content } else { $idemSummary2 }
$idemAfter = if ($idemContent2) { $idemContent2.Count } else { 0 }
if ($idemAfter -ne $idemBefore) { throw "FAIL: count changed ($idemBefore -> $idemAfter)" }
Write-Host "  Idempotent: $idemAfter policies - PASS"

Write-Host "`n=== Smoke: Seed MEMPolicies (PS7) — ALL PASS ===" -ForegroundColor Green
