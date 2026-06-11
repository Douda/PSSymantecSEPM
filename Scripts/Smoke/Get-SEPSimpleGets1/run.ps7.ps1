<#
.SYNOPSIS
    PS7 entry point for Get-SEPSimpleGets1 smoke tests.

.DESCRIPTION
    Bootstraps the module and SEPM connection for PS 7+, then dot-sources
    Common-Shared.ps1 (auth + helpers) and Tests.ps1 (test cases).

    Usage: pwsh -NoProfile -File Scripts/Smoke/Get-SEPSimpleGets1/run.ps7.ps1
#>

$ErrorActionPreference = "Continue"
$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path

# ── Module import ──
$OutputRoot = Join-Path -Path $RepoRoot -ChildPath 'Output'
$env:PSModulePath = "$OutputRoot$([System.IO.Path]::PathSeparator)$env:PSModulePath"
$ModulePath = Join-Path -Path $OutputRoot -ChildPath 'PSSymantecSEPM/PSSymantecSEPM.psm1'
Import-Module $ModulePath -Force

$SmokeModule = Get-Module PSSymantecSEPM
& $SmokeModule { $script:SkipCert = $true }

# ── SEPM connection ──
Set-SepmConfiguration -ServerAddress 'localhost' -Port 8446 -ErrorAction SilentlyContinue

# ── Clean stale credential/token files ──
Remove-Item -Path "$HOME/.config/PSSymantecSEPM/creds.xml" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$HOME/.local/share/PSSymantecSEPM/accessToken.xml" -Force -ErrorAction SilentlyContinue

# ── Shared infrastructure + tests ──
. "$RepoRoot/Scripts/Smoke/Common-Shared.ps1"
. "$RepoRoot/Scripts/Smoke/Get-SEPSimpleGets1/Tests.ps1"
