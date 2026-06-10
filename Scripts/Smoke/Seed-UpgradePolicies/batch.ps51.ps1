# Smoke verification for UpgradePolicies seed (PS5.1)
# Run via: python3 Scripts/invoke-winrm.py 'C:\Users\smokeuser\Desktop\Shared\smoke-upgrade.ps1'

$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"
. "$RepoRoot\Common-PS51.ps1"

Write-Host "=== Smoke: Seed UpgradePolicies (PS5.1) ==="

$seedScript = Join-Path -Path $RepoRoot -ChildPath 'Seed-SEPMData.ps1'

# ── Clean state: delete existing seed policies if any ──
$session = & (Get-Module PSSymantecSEPM) { Initialize-SEPMSession }
$summary = Invoke-SepmApi -Method GET -Uri "$($session.BaseURLv1)/policies/summary/upgrade" -Session $session
$seedNames = @('Zero-Day Upgrade', 'Weekend Upgrade', 'Manual Upgrade')
$content = if ($summary.ContainsKey('content')) { $summary.content } else { $summary }
if ($content) {
    foreach ($p in $content) {
        if ($p.name -in $seedNames) {
            $disableBody = @{ name = $p.name; enabled = $false } | ConvertTo-Json
            Invoke-SepmApi -Method PATCH -Uri "$($session.BaseURLv1)/policies/upgrade/$($p.id)" -Session $session -Body $disableBody
            Invoke-SepmApi -Method DELETE -Uri "$($session.BaseURLv1)/policies/upgrade/$($p.id)" -Session $session
        }
    }
}

# ── Baseline after cleanup ──
$beforeSummary = Invoke-SepmApi -Method GET -Uri "$($session.BaseURLv1)/policies/summary/upgrade" -Session $session
$beforeContent = if ($beforeSummary.ContainsKey('content')) { $beforeSummary.content } else { $beforeSummary }
$beforeCount = if ($beforeContent) { $beforeContent.Count } else { 0 }
Write-Host "Before: $beforeCount Upgrade policies"

# ── Seed ──
Write-Host "--- Seeding UpgradePolicies ---"
$result = & $seedScript -Categories UpgradePolicies 6>&1

$outputText = if ($null -eq $result) { '' } elseif ($result -is [array]) { $result -join "`n" } else { $result.ToString() }
if ($outputText -notmatch 'Upgrade policies seeded: 3') {
    throw "FAIL: expected 'Upgrade policies seeded: 3', got: $outputText"
}

# Refresh session after orchestrator reimported the module
$session = & (Get-Module PSSymantecSEPM) { Initialize-SEPMSession }

# ── Verify count +3 ──
$afterSummary = Invoke-SepmApi -Method GET -Uri "$($session.BaseURLv1)/policies/summary/upgrade" -Session $session
$afterContent = if ($afterSummary.ContainsKey('content')) { $afterSummary.content } else { $afterSummary }
$afterCount = if ($afterContent) { $afterContent.Count } else { 0 }
Write-Host "After: $afterCount Upgrade policies"
if ($afterCount -ne ($beforeCount + 3)) {
    throw "FAIL: expected $($beforeCount + 3) policies, got $afterCount"
}

# ── Verify policy names ──
$policyNames = if ($afterContent) { $afterContent.name } else { @() }
foreach ($n in $seedNames) {
    if ($n -notin $policyNames) { throw "FAIL: policy '$n' not found" }
}
Write-Host "  All 3 policy names present"

# Helper: get full policy by name
function Get-UpgradePolicyByName($name) {
    $s = & (Get-Module PSSymantecSEPM) { Initialize-SEPMSession }
    $sum = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/upgrade" -Session $s
    $c = if ($sum.ContainsKey('content')) { $sum.content } else { $sum }
    $match = $c | Where-Object { $_.name -eq $name } | Select-Object -First 1
    if (-not $match) { return $null }
    $full = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/upgrade/$($match.id)" -Session $s
    return $full
}

# ── Verify Zero-Day Upgrade config ──
Write-Host "--- Verify Zero-Day Upgrade ---"
$zd = Get-UpgradePolicyByName 'Zero-Day Upgrade'
if (-not $zd) { throw "FAIL: Zero-Day Upgrade not found" }
if ($zd.enabled -ne $true) { throw "FAIL: Zero-Day enabled should be true, got: $($zd.enabled)" }
if ($zd.configuration.release_delay_days -ne 0) { throw "FAIL: Zero-Day release_delay_days should be 0, got: $($zd.configuration.release_delay_days)" }
if ($zd.configuration.schedule.retry_enabled -ne $true) { throw "FAIL: Zero-Day retry_enabled should be true" }
if ($zd.configuration.schedule.time_window -ne 86400) { throw "FAIL: Zero-Day time_window should be 86400, got: $($zd.configuration.schedule.time_window)" }
$daily = $zd.configuration.schedule.daily
if ($daily.monday -ne $true -or $daily.tuesday -ne $true -or $daily.wednesday -ne $true -or
    $daily.thursday -ne $true -or $daily.friday -ne $true -or $daily.saturday -ne $true -or $daily.sunday -ne $true) {
    throw "FAIL: Zero-Day should have all 7 days enabled"
}
Write-Host "  Zero-Day: delay=0 all_days=true retry=true window=86400 - PASS"

# ── Verify Weekend Upgrade config ──
Write-Host "--- Verify Weekend Upgrade ---"
$we = Get-UpgradePolicyByName 'Weekend Upgrade'
if (-not $we) { throw "FAIL: Weekend Upgrade not found" }
if ($we.enabled -ne $true) { throw "FAIL: Weekend enabled should be true, got: $($we.enabled)" }
if ($we.configuration.release_delay_days -ne 7) { throw "FAIL: Weekend release_delay_days should be 7, got: $($we.configuration.release_delay_days)" }
if ($we.configuration.schedule.retry_enabled -ne $true) { throw "FAIL: Weekend retry_enabled should be true" }
if ($we.configuration.schedule.time_window -ne 14400) { throw "FAIL: Weekend time_window should be 14400, got: $($we.configuration.schedule.time_window)" }
$wdaily = $we.configuration.schedule.daily
if ($wdaily.saturday -ne $true -or $wdaily.sunday -ne $true) {
    throw "FAIL: Weekend should have Saturday+Sunday enabled"
}
if ($wdaily.monday -ne $false -or $wdaily.tuesday -ne $false -or $wdaily.wednesday -ne $false -or
    $wdaily.thursday -ne $false -or $wdaily.friday -ne $false) {
    throw "FAIL: Weekend should have weekdays disabled"
}
Write-Host "  Weekend: delay=7 sat+sun=true retry=true window=14400 - PASS"

# ── Verify Manual Upgrade config ──
Write-Host "--- Verify Manual Upgrade ---"
$mu = Get-UpgradePolicyByName 'Manual Upgrade'
if (-not $mu) { throw "FAIL: Manual Upgrade not found" }
if ($mu.enabled -ne $false) { throw "FAIL: Manual enabled should be false, got: $($mu.enabled)" }
Write-Host "  Manual: enabled=$($mu.enabled) - PASS"

# ── Idempotency ──
Write-Host "--- Idempotency ---"
$sess2 = & (Get-Module PSSymantecSEPM) { Initialize-SEPMSession }
$sumIdem = Invoke-SepmApi -Method GET -Uri "$($sess2.BaseURLv1)/policies/summary/upgrade" -Session $sess2
$contentIdem = if ($sumIdem.ContainsKey('content')) { $sumIdem.content } else { $sumIdem }
$idemBefore = if ($contentIdem) { $contentIdem.Count } else { 0 }
$result = & $seedScript -Categories UpgradePolicies 6>&1
$sumIdem2 = Invoke-SepmApi -Method GET -Uri "$($sess2.BaseURLv1)/policies/summary/upgrade" -Session $sess2
$contentIdem2 = if ($sumIdem2.ContainsKey('content')) { $sumIdem2.content } else { $sumIdem2 }
$idemAfter = if ($contentIdem2) { $contentIdem2.Count } else { 0 }
if ($idemAfter -ne $idemBefore) { throw "FAIL: count changed ($idemBefore -> $idemAfter)" }
Write-Host "  Idempotent: $idemAfter policies - PASS"

Write-Host "`n=== Smoke: Seed UpgradePolicies (PS5.1) — ALL PASS ===" -ForegroundColor Green
