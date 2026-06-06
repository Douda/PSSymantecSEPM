# Smoke test for Update-SEPMExceptionPolicy
# Tests against the local SEPM VM (localhost:8446)
param(
    [switch]$SkipPS51
)

$ErrorActionPreference = 'Continue'
Write-Host "PowerShell $($PSVersionTable.PSVersion)" -ForegroundColor Cyan

# === Config ===
$sepAddress = 'localhost'
$sepPort = 8446

# Ensure config file is correct
$configPath = Join-Path ([Environment]::GetFolderPath('ApplicationData')) 'PSSymantecSEPM/config.json'
$configDir = Split-Path $configPath -Parent
if (-not (Test-Path $configDir)) { New-Item -ItemType Directory -Path $configDir -Force | Out-Null }
@{ port = $sepPort; ServerAddress = $sepAddress } | ConvertTo-Json | Set-Content -Path $configPath -Force
Write-Host "[CONFIG] OK" -ForegroundColor Cyan

# Clear token cache to force fresh auth
$tokenPath = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'PSSymantecSEPM/accessToken.xml'
Remove-Item $tokenPath -Force -ErrorAction SilentlyContinue

# === Import module ===
$modulePath = Join-Path $PSScriptRoot '..' 'Output' 'PSSymantecSEPM' 'PSSymantecSEPM.psm1'
Import-Module $modulePath -Force
Write-Host "[MODULE] Imported" -ForegroundColor Cyan

# Set SkipCert in module scope
$mod = Get-Module PSSymantecSEPM
& $mod { $script:SkipCert = $true }
Write-Host "[CERT] SkipCert = true" -ForegroundColor Cyan

# === Auth ===
Write-Host "`n=== AUTHENTICATION ===" -ForegroundColor Yellow
try {
    $token = Get-SEPMAccessToken
    Write-Host "[OK] Token obtained" -ForegroundColor Green
} catch {
    Write-Host "[FAIL] Auth: $_" -ForegroundColor Red
    exit 1
}

# === Verify basic connectivity ===
Write-Host "`n=== BASIC SMOKE ===" -ForegroundColor Yellow
$version = Get-SEPMVersion
if ($version.API_VERSION) {
    Write-Host "[OK] SEPM $($version.version) (API $($version.API_VERSION))" -ForegroundColor Green
} else {
    Write-Host "[FAIL] Get-SEPMVersion returned unexpected: $version" -ForegroundColor Red
    exit 1
}

# === Find test policy ===
Write-Host "`n=== EXCEPTION POLICY SMOKE ===" -ForegroundColor Yellow
$testPolicyName = 'Exceptions policy'

$policies = Get-SEPMPoliciesSummary
$testPolicy = $policies | Where-Object { $_.name -eq $testPolicyName }

if (-not $testPolicy) {
    Write-Host "[FAIL] Policy '$testPolicyName' not found!" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Using policy: $($testPolicy.name) (ID: $($testPolicy.id))" -ForegroundColor Green

# === GET existing state (raw, avoid ConvertFrom-Json double-parsing) ===
Write-Host "`n--- Current exception policy state ---" -ForegroundColor Yellow
try {
    $session = Initialize-SEPMSession
    $URI = $session.BaseURLv2 + "/policies/exceptions/" + $testPolicy.id
    $params = @{
        Session = $session
        Method  = 'GET'
        Uri     = $URI
    }
    $rawResp = Invoke-ABRestMethod -params $params
    if ($rawResp -is [string] -and $rawResp -like 'Error:*') {
        Write-Host "[FAIL] Raw GET returned error: $rawResp" -ForegroundColor Red
        exit 1
    }
    Write-Host "[OK] Raw response type: $($rawResp.GetType().Name)" -ForegroundColor Green
    $filesBefore = @($rawResp.configuration.files)
    Write-Host "[INFO] Current file exceptions: $($filesBefore.Count)" -ForegroundColor Gray
} catch {
    Write-Host "[FAIL] Raw GET: $_" -ForegroundColor Red
}

# === TEST: Add a file exception via Update-SEPMExceptionPolicy ===
Write-Host "`n--- Update-SEPMExceptionPolicy -WindowsFile (ADD) ---" -ForegroundColor Yellow
$testPath = 'C:\Temp\SmokeTest_Exception.exe'

try {
    $result = Update-SEPMExceptionPolicy -PolicyName $testPolicyName -Path $testPath -AllScans
    Write-Host "[OK] Update-SEPMExceptionPolicy completed" -ForegroundColor Green
    Write-Host "  Response name: $($result.name)"
    Write-Host "  Response enabled: $($result.enabled)"
} catch {
    Write-Host "[FAIL] Update-SEPMExceptionPolicy (ADD): $_" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor DarkYellow
}

# === VERIFY: Raw GET to check if file was added ===
Write-Host "`n--- VERIFY after ADD ---" -ForegroundColor Yellow
try {
    $session = Initialize-SEPMSession
    $URI = $session.BaseURLv2 + "/policies/exceptions/" + $testPolicy.id
    $params = @{ Session = $session; Method = 'GET'; Uri = $URI }
    $rawAfter = Invoke-ABRestMethod -params $params
    $filesAfter = @($rawAfter.configuration.files)
    $added = $filesAfter | Where-Object { $_.path -eq $testPath -and -not $_.deleted }
    if ($added) {
        Write-Host "[OK] File '$testPath' ADDED and ACTIVE!" -ForegroundColor Green
        $added | ForEach-Object {
            Write-Host "  SONAR=$($_.SONAR) AppControl=$($_.applicationcontrol) SecurityRisk=$($_.securityrisk)"
        }
    } else {
        Write-Host "[FAIL] File '$testPath' NOT found after add!" -ForegroundColor Red
        if ($filesAfter.Count -gt 0) {
            $filesAfter | Select-Object path, deleted | Format-Table -AutoSize
        }
    }
} catch {
    Write-Host "[FAIL] Verify: $_" -ForegroundColor Red
}

# === TEST: Remove the file exception ===
Write-Host "`n--- Update-SEPMExceptionPolicy -WindowsFile (REMOVE) ---" -ForegroundColor Yellow
try {
    $result2 = Update-SEPMExceptionPolicy -PolicyName $testPolicyName -Path $testPath -AllScans -Remove
    Write-Host "[OK] Remove completed" -ForegroundColor Green
} catch {
    Write-Host "[FAIL] Remove: $_" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor DarkYellow
}

# === VERIFY: File was removed ===
Write-Host "`n--- VERIFY after REMOVE ---" -ForegroundColor Yellow
try {
    $session = Initialize-SEPMSession
    $URI = $session.BaseURLv2 + "/policies/exceptions/" + $testPolicy.id
    $params = @{ Session = $session; Method = 'GET'; Uri = $URI }
    $rawAfterRemove = Invoke-ABRestMethod -params $params
    $filesAfterRemove = @($rawAfterRemove.configuration.files)
    $stillActive = $filesAfterRemove | Where-Object { $_.path -eq $testPath -and -not $_.deleted }
    if ($stillActive) {
        Write-Host "[FAIL] File '$testPath' still ACTIVE!" -ForegroundColor Red
    } else {
        Write-Host "[OK] File '$testPath' no longer active" -ForegroundColor Green
    }
} catch {
    Write-Host "[FAIL] Verify: $_" -ForegroundColor Red
}

Write-Host "`n=== SMOKE TEST COMPLETE (PS $($PSVersionTable.PSVersion)) ===" -ForegroundColor Cyan
