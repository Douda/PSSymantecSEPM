<#
.SYNOPSIS
    Shared initialization for all PSSymantecSEPM smoke scripts (PS5.1).

.DESCRIPTION
    Dot-source this from any batch.ps51.ps1 smoke script running on the Windows VM.
    It handles:
      - TLS 1.2 + certificate bypass
      - Module import from shared volume
      - SEPM connection configuration
      - Authentication (token acquisition)

    Deploy this file to C:\Users\smokeuser\Desktop\Shared\ before running smoke scripts.

    The caller must set $RepoRoot before dot-sourcing:

        $RepoRoot = "C:\Users\smokeuser\Desktop\Shared"
        . "$RepoRoot\Common-PS51.ps1"

.NOTES
    Credentials are centralized here. Change once, all PS5.1 smoke scripts update.
#>

$ErrorActionPreference = "Continue"

# ── PS5.1 transport prerequisites ──
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

# ── SEPM configuration ──
$cfg = "$env:APPDATA\PSSymantecSEPM\config.json"
New-Item -ItemType Directory (Split-Path $cfg) -Force | Out-Null
@{ port = 8446; ServerAddress = "localhost" } | ConvertTo-Json | Set-Content $cfg -Force

# ── Module import ──
$ModulePath = "$RepoRoot\PSSymantecSEPM\PSSymantecSEPM.psm1"
Import-Module $ModulePath -Force

$SmokeModule = Get-Module PSSymantecSEPM
& $SmokeModule { $script:SkipCert = $true }

# Ensure the seed script can find PSSymantecSEPM via Import-Module
$env:PSModulePath = "$RepoRoot;$env:PSModulePath"

# ── Authentication ──
$SmokeCredPassword = ConvertTo-SecureString -String 'MyComplexPassword1!' -AsPlainText -Force
$SmokeCredential   = New-Object System.Management.Automation.PSCredential -ArgumentList 'admin', $SmokeCredPassword
Set-SEPMAuthentication -Credential $SmokeCredential -ErrorAction SilentlyContinue

# ── Shared helpers ──
function T {
    param($Id, $Label, [ScriptBlock]$Action, [ScriptBlock]$Assert)
    Write-Host "--- $Id : $Label ---" -ForegroundColor Cyan
    try {
        $result = & $Action

        if ($result -is [string] -and $result -like "Error:*") {
            Write-Host "  VERDICT: FAIL (API error: $result)" -ForegroundColor Red
            return "FAIL"
        }

        $ok = & $Assert $result
        if ($ok) { Write-Host "  VERDICT: PASS" -ForegroundColor Green; return "PASS" }
        else     { Write-Host "  VERDICT: FAIL" -ForegroundColor Red;   return "FAIL" }
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        return "FAIL"
    }
}

function Skip {
    param($Id, $Label, $Reason)
    Write-Host "--- $Id : $Label ---" -ForegroundColor Cyan
    Write-Host "  SKIP: $Reason" -ForegroundColor Yellow
    return "SKIP"
}
