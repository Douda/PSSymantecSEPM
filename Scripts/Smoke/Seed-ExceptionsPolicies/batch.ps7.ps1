# Smoke verification for ExceptionsPolicies seed (PS7)
# Usage: pwsh -NoProfile -File Scripts/Smoke/Seed-ExceptionsPolicies/batch.ps7.ps1

$ErrorActionPreference = "Continue"

$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"

Write-Host "=== Smoke: Seed ExceptionsPolicies (PS7) ==="

$seedScript = Join-Path -Path $RepoRoot -ChildPath 'Scripts/Seed-SEPMData.ps1'

# ── Clean state: delete existing seed policies if any ──
$session = & (Get-Module PSSymantecSEPM) { Initialize-SEPMSession }
$summary = Invoke-SepmApi -Method GET -Uri "$($session.BaseURLv1)/policies/summary/exceptions" -Session $session
$seedNames = @('Standard Workstation Exceptions', 'Server Exceptions', 'Developer Exceptions', 'Emergency Disabled')
foreach ($p in $summary.content) {
    if ($p.name -in $seedNames) {
        $disableBody = @{ name = $p.name; enabled = $false } | ConvertTo-Json
        Invoke-SepmApi -Method PATCH -Uri "$($session.BaseURLv1)/policies/exceptions/$($p.id)" -Session $session -Body $disableBody
        Invoke-SepmApi -Method DELETE -Uri "$($session.BaseURLv1)/policies/exceptions/$($p.id)" -Session $session
    }
}

# ── Baseline after cleanup ──
$beforeCount = @(Get-SEPMPoliciesSummary | Where-Object { $_.policytype -eq 'exceptions' }).Count
Write-Host "Before: $beforeCount exceptions policies"

# ── Seed ──
Write-Host "--- Seeding ExceptionsPolicies ---"
$result = & $seedScript -Categories ExceptionsPolicies 6>&1

$outputText = if ($result -is [array]) { $result -join "`n" } else { $result.ToString() }
if ($outputText -notmatch 'Exceptions policies seeded: 4') {
    throw "FAIL: expected 'Exceptions policies seeded: 4', got: $outputText"
}

# ── Verify count +4 ──
$afterCount = @(Get-SEPMPoliciesSummary | Where-Object { $_.policytype -eq 'exceptions' }).Count
Write-Host "After: $afterCount exceptions policies"
if ($afterCount -ne ($beforeCount + 4)) {
    throw "FAIL: expected $($beforeCount + 4) policies, got $afterCount"
}

# ── Verify policy names ──
$exceptionsSummary = Get-SEPMPoliciesSummary | Where-Object { $_.policytype -eq 'exceptions' }
$policyNames = $exceptionsSummary.name
$seedNames | ForEach-Object {
    if ($_ -notin $policyNames) { throw "FAIL: policy '$_' not found" }
}
Write-Host "  All 4 policy names present"

# ── Verify Standard Workstation config ──
Write-Host "--- Verify Standard Workstation config ---"
$stdPolicy = Get-SEPMExceptionPolicy -PolicyName 'Standard Workstation Exceptions'
if (-not $stdPolicy) { throw "FAIL: Get-SEPMExceptionPolicy returned null" }
if ($stdPolicy.enabled -ne $true) { throw "FAIL: Standard Workstation should be enabled" }
$files = Get-SEPMExceptionPolicy -PolicyName 'Standard Workstation Exceptions' -List files
$dirs = Get-SEPMExceptionPolicy -PolicyName 'Standard Workstation Exceptions' -List directories
$exts = Get-SEPMExceptionPolicy -PolicyName 'Standard Workstation Exceptions' -List extensions
if ($files.Count -lt 3) { throw "FAIL: expected >= 3 files, got $($files.Count)" }
if ($dirs.Count -lt 2) { throw "FAIL: expected >= 2 dirs, got $($dirs.Count)" }
if ($exts.Count -lt 1) { throw "FAIL: expected >= 1 extension, got $($exts.Count)" }
Write-Host "  Standard: $($files.Count) files, $($dirs.Count) dirs, $($exts.Count) exts - PASS"

# ── Verify Server Exceptions (tamper only) ──
Write-Host "--- Verify Server Exceptions config ---"
$srvPolicy = Get-SEPMExceptionPolicy -PolicyName 'Server Exceptions'
if ($srvPolicy.enabled -ne $true) { throw "FAIL: Server should be enabled" }
$srvTamper = Get-SEPMExceptionPolicy -PolicyName 'Server Exceptions' -List tamper
if ($srvTamper.Count -lt 1) { throw "FAIL: Server should have tamper rules" }
Write-Host "  Server: $($srvTamper.Count) tamper rules - PASS"

# ── Verify Developer Exceptions ──
Write-Host "--- Verify Developer Exceptions config ---"
$devPolicy = Get-SEPMExceptionPolicy -PolicyName 'Developer Exceptions'
if ($devPolicy.enabled -ne $true) { throw "FAIL: Developer should be enabled" }
$devDirs = Get-SEPMExceptionPolicy -PolicyName 'Developer Exceptions' -List directories
if ($devDirs.Count -lt 2) { throw "FAIL: Developer should have >= 2 dirs" }
$allRecursive = ($devDirs | Where-Object { $_.scantype -eq 'All' -and $_.recursive -eq $true }).Count
if ($allRecursive -lt 2) { throw "FAIL: Developer should have broad recursive dirs" }
Write-Host "  Developer: $($devDirs.Count) dirs, $allRecursive broad recursive - PASS"

# ── Verify Emergency Disabled is disabled ──
Write-Host "--- Verify Emergency Disabled ---"
$emPolicy = Get-SEPMExceptionPolicy -PolicyName 'Emergency Disabled'
if ($emPolicy.enabled -ne $false) { throw "FAIL: Emergency should be disabled" }
Write-Host "  Emergency: enabled=$($emPolicy.enabled) - PASS"

# ── Idempotency ──
Write-Host "--- Idempotency ---"
$idemBefore = @(Get-SEPMPoliciesSummary | Where-Object { $_.policytype -eq 'exceptions' }).Count
$result = & $seedScript -Categories ExceptionsPolicies 6>&1
$idemAfter = @(Get-SEPMPoliciesSummary | Where-Object { $_.policytype -eq 'exceptions' }).Count
if ($idemAfter -ne $idemBefore) { throw "FAIL: count changed ($idemBefore -> $idemAfter)" }
Write-Host "  Idempotent: $idemAfter policies - PASS"

Write-Host "`n=== Smoke: Seed ExceptionsPolicies (PS7) — ALL PASS ===" -ForegroundColor Green
