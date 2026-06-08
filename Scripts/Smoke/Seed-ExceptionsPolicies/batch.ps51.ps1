# Smoke verification for ExceptionsPolicies seed (PS5.1)
# Usage: deployed to C:\Users\smokeuser\Desktop\Shared\ and run via WinRM

$ErrorActionPreference = "Continue"

$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"
. "$RepoRoot\Common-PS51.ps1"

Write-Host "=== Smoke: Seed ExceptionsPolicies (PS5.1) ==="

$seedScript = Join-Path -Path $RepoRoot -ChildPath 'Seed-SEPMData.ps1'

# Clean state: use -Force to delete and recreate
Write-Host "--- Clean via -Force ---"
$null = & $seedScript -Categories ExceptionsPolicies -Force

# Verify count after Force reset
$allBefore = Get-SEPMPoliciesSummary
$exBefore = @($allBefore | Where-Object { $_.policytype -eq 'exceptions' })
$beforeCount = $exBefore.Count
Write-Host "After Force: $beforeCount exceptions policies"

# Verify policy names exist
$policyNames = $exBefore | ForEach-Object { $_.name }
$seedNames = @('Standard Workstation Exceptions', 'Server Exceptions', 'Developer Exceptions', 'Emergency Disabled')
$seedNames | ForEach-Object {
    if ($_ -notin $policyNames) { throw "FAIL: policy '$_' not found after Force" }
}
Write-Host "  All 4 policy names present"

# Verify Standard Workstation config
Write-Host "--- Verify Standard Workstation config ---"
$stdPolicy = Get-SEPMExceptionPolicy -PolicyName 'Standard Workstation Exceptions'
if ($stdPolicy.enabled -ne $true) { throw "FAIL: Standard should be enabled" }
$files = @(Get-SEPMExceptionPolicy -PolicyName 'Standard Workstation Exceptions' -List files)
$dirs = @(Get-SEPMExceptionPolicy -PolicyName 'Standard Workstation Exceptions' -List directories)
$exts = @(Get-SEPMExceptionPolicy -PolicyName 'Standard Workstation Exceptions' -List extensions)
if ($files.Count -lt 3) { throw "FAIL: expected >= 3 files, got $($files.Count)" }
if ($dirs.Count -lt 2) { throw "FAIL: expected >= 2 dirs, got $($dirs.Count)" }
if ($exts.Count -lt 1) {
    # PS5.1 fallback: extension_list may not have array-wrapped extensions
    $stdFull = Get-SEPMExceptionPolicy -PolicyName 'Standard Workstation Exceptions'
    $exts = @($stdFull.configuration.extension_list.extensions)
}
if ($exts.Count -lt 1) { throw "FAIL: expected >= 1 extension, got $($exts.Count)" }
Write-Host "  Standard: $($files.Count) files, $($dirs.Count) dirs, $($exts.Count) exts - PASS"

# Verify Server Exceptions
Write-Host "--- Verify Server Exceptions config ---"
$srvPolicy = Get-SEPMExceptionPolicy -PolicyName 'Server Exceptions'
if ($srvPolicy.enabled -ne $true) { throw "FAIL: Server should be enabled" }
$srvTamper = @(Get-SEPMExceptionPolicy -PolicyName 'Server Exceptions' -List tamper)
if ($srvTamper.Count -lt 1) { throw "FAIL: Server should have tamper rules" }
Write-Host "  Server: $($srvTamper.Count) tamper rules - PASS"

# Verify Developer Exceptions
Write-Host "--- Verify Developer Exceptions config ---"
$devPolicy = Get-SEPMExceptionPolicy -PolicyName 'Developer Exceptions'
if ($devPolicy.enabled -ne $true) { throw "FAIL: Developer should be enabled" }
$devDirs = @(Get-SEPMExceptionPolicy -PolicyName 'Developer Exceptions' -List directories)
if ($devDirs.Count -lt 2) { throw "FAIL: Developer should have >= 2 dirs" }
$allRecursive = @($devDirs | Where-Object { $_.scantype -eq 'All' -and $_.recursive -eq $true }).Count
if ($allRecursive -lt 2) { throw "FAIL: Developer should have broad recursive dirs" }
Write-Host "  Developer: $($devDirs.Count) dirs, $allRecursive broad recursive - PASS"

# Verify Emergency Disabled
Write-Host "--- Verify Emergency Disabled ---"
$emPolicy = Get-SEPMExceptionPolicy -PolicyName 'Emergency Disabled'
if ($emPolicy.enabled -ne $false) { throw "FAIL: Emergency should be disabled" }
Write-Host "  Emergency: enabled=$($emPolicy.enabled) - PASS"

# Idempotency
Write-Host "--- Idempotency ---"
$idemAll = Get-SEPMPoliciesSummary
$idemEx = @($idemAll | Where-Object { $_.policytype -eq 'exceptions' })
$idemBefore = $idemEx.Count
$null = & $seedScript -Categories ExceptionsPolicies
$idemAll2 = Get-SEPMPoliciesSummary
$idemEx2 = @($idemAll2 | Where-Object { $_.policytype -eq 'exceptions' })
$idemAfter = $idemEx2.Count
if ($idemAfter -ne $idemBefore) { throw "FAIL: count changed ($idemBefore -> $idemAfter)" }
Write-Host "  Idempotent: $idemAfter policies - PASS"

Write-Host "`n=== Smoke: Seed ExceptionsPolicies (PS5.1) — ALL PASS ===" -ForegroundColor Green
