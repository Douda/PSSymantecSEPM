# PS 7 Metadata Smoke Test
# Tests: EnablePolicy, DisablePolicy, PolicyDescription (metadata only — no file rules)
Import-Module ./Output/PSSymantecSEPM/PSSymantecSEPM.psm1 -Force
$mod = Get-Module PSSymantecSEPM
& $mod { $script:SkipCert = $true }

$ErrorActionPreference = "Continue"
$policyName = "Exceptions policy"

Write-Host "=== PS 7 Metadata Smoke Test ===" -ForegroundColor Yellow

function Get-PolicyState {
    $s = Initialize-SEPMSession
    $uri = $s.BaseURLv2 + "/policies/exceptions/4C4BC60CAC1E00027A25369C305828F9"
    $p = @{ Session = $s; Method = "GET"; Uri = $uri }
    $r = Invoke-ABRestMethod -params $p
    return @{ enabled = $r.enabled; desc = $r.desc }
}

# Record original
$orig = Get-PolicyState
Write-Host "Original: enabled=$($orig.enabled), desc=$($orig.desc)" -ForegroundColor Cyan

# Test 1: DisablePolicy
Write-Host "`n1. DisablePolicy..." -ForegroundColor Yellow
Update-SEPMExceptionPolicy -PolicyName $policyName -DisablePolicy
$s = Get-PolicyState
if ($s.enabled -eq $false) { Write-Host "   PASS: enabled=False" -ForegroundColor Green }
else { Write-Host "   FAIL: enabled=$($s.enabled)" -ForegroundColor Red }

# Test 2: EnablePolicy
Write-Host "2. EnablePolicy..." -ForegroundColor Yellow
Update-SEPMExceptionPolicy -PolicyName $policyName -EnablePolicy
$s = Get-PolicyState
if ($s.enabled -eq $true) { Write-Host "   PASS: enabled=True" -ForegroundColor Green }
else { Write-Host "   FAIL: enabled=$($s.enabled)" -ForegroundColor Red }

# Test 3: PolicyDescription
Write-Host "3. PolicyDescription..." -ForegroundColor Yellow
$desc = "PS7 smoke $(Get-Date -Format HH:mm:ss)"
Update-SEPMExceptionPolicy -PolicyName $policyName -PolicyDescription $desc
$s = Get-PolicyState
if ($s.desc -eq $desc) { Write-Host "   PASS: desc='$($s.desc)'" -ForegroundColor Green }
else { Write-Host "   FAIL: desc='$($s.desc)'" -ForegroundColor Red }

# Test 4: EnablePolicy + PolicyDescription combined
Write-Host "4. EnablePolicy + PolicyDescription..." -ForegroundColor Yellow
$desc2 = "PS7 combined $(Get-Date -Format HH:mm:ss)"
Update-SEPMExceptionPolicy -PolicyName $policyName -EnablePolicy -PolicyDescription $desc2
$s = Get-PolicyState
if ($s.enabled -eq $true -and $s.desc -eq $desc2) {
    Write-Host "   PASS: enabled=True, desc='$($s.desc)'" -ForegroundColor Green
} else {
    Write-Host "   FAIL: enabled=$($s.enabled), desc='$($s.desc)'" -ForegroundColor Red
}

# Test 5: EnablePolicy + DisablePolicy conflict
Write-Host "5. EnablePolicy + DisablePolicy conflict..." -ForegroundColor Yellow
try {
    Update-SEPMExceptionPolicy -PolicyName $policyName -EnablePolicy -DisablePolicy
    Write-Host "   FAIL: No error thrown" -ForegroundColor Red
} catch {
    if ($_.Exception.Message -match "EnablePolicy.*DisablePolicy") {
        Write-Host "   PASS: Error thrown" -ForegroundColor Green
    } else {
        Write-Host "   FAIL: Wrong error: $_" -ForegroundColor Red
    }
}

# Restore
Write-Host "`nRestoring original state..." -ForegroundColor Yellow
Update-SEPMExceptionPolicy -PolicyName $policyName -EnablePolicy -PolicyDescription $orig.desc
$s = Get-PolicyState
if ($s.enabled -eq $true -and $s.desc -eq $orig.desc) {
    Write-Host "RESTORE: OK" -ForegroundColor Green
} else {
    Write-Host "RESTORE: FAIL" -ForegroundColor Red
}

Write-Host "`n=== PS 7 Smoke Test Complete ===" -ForegroundColor Green
