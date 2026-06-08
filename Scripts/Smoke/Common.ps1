<#
.SYNOPSIS
    Shared initialization for all PSSymantecSEPM smoke scripts (PS7).

.DESCRIPTION
    Dot-source this from any batch.ps7.ps1 smoke script. It handles:
      - Module import from Output/
      - Certificate bypass (SkipCert)
      - SEPM connection configuration
      - Authentication (token acquisition)

    The caller must set $RepoRoot before dot-sourcing:

        $RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
        . "$RepoRoot/Scripts/Smoke/Common.ps1"

.NOTES
    Credentials are centralized here. Change once, all smoke scripts update.
#>

#Requires -Version 7.0

$ErrorActionPreference = "Continue"

# ── Module import ──
$OutputRoot = Join-Path -Path $RepoRoot -ChildPath 'Output'
$env:PSModulePath = "$OutputRoot$([System.IO.Path]::PathSeparator)$env:PSModulePath"

$ModulePath = Join-Path -Path $OutputRoot -ChildPath 'PSSymantecSEPM/PSSymantecSEPM.psm1'
Import-Module $ModulePath -Force

$SmokeModule = Get-Module PSSymantecSEPM
& $SmokeModule { $script:SkipCert = $true }

# ── SEPM connection ──
Set-SepmConfiguration -ServerAddress 'localhost' -Port 8446 -ErrorAction SilentlyContinue

# ── Authentication ──
# Clean stale empty creds/token files left by test runner
Remove-Item -Path "$HOME/.config/PSSymantecSEPM/creds.xml" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$HOME/.local/share/PSSymantecSEPM/accessToken.xml" -Force -ErrorAction SilentlyContinue

$SmokeCredPassword = ConvertTo-SecureString -String 'MyComplexPassword1!' -AsPlainText -Force
$SmokeCredential   = New-Object System.Management.Automation.PSCredential -ArgumentList 'admin', $SmokeCredPassword
Set-SEPMAuthentication -Credential $SmokeCredential -ErrorAction SilentlyContinue

Get-SEPMAccessToken | Out-Null

# ── Shared helper: T (test runner) ──
function T {
    <#
    .SYNOPSIS
        Standard smoke test runner for GET cmdlets.
    .PARAMETER Id
        Test ID (A1, B3, etc.)
    .PARAMETER Label
        Human-readable test description.
    .PARAMETER Action
        ScriptBlock that calls the cmdlet.
    .PARAMETER Assert
        ScriptBlock that receives output and returns $true/$false.
    #>
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

# ── Shared helper: Skip (explicit skip) ──
function Skip {
    param($Id, $Label, $Reason)
    Write-Host "--- $Id : $Label ---" -ForegroundColor Cyan
    Write-Host "  SKIP: $Reason" -ForegroundColor Yellow
    return "SKIP"
}
