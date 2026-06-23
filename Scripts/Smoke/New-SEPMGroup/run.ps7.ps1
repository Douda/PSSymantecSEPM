<#
.SYNOPSIS
    PS7 entry point for New-SEPMGroup smoke tests.

.DESCRIPTION
    Bootstraps the module and SEPM connection for PS 7+, then dot-sources
    Common.ps1 (auth + helpers) and Tests.ps1 (test cases).

    Usage: pwsh -NoProfile -File Scripts/Smoke/New-SEPMGroup/run.ps7.ps1
#>

#Requires -Version 7.0

$ErrorActionPreference = "Continue"
$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path

# ── Bootstrap: import module, cert bypass, config, auth ──
. "$RepoRoot/Scripts/Smoke/Bootstrap.ps1"
Initialize-SmokeBootstrap -RepoRoot $RepoRoot

# ── Shared infrastructure + tests ──
. "$RepoRoot/Scripts/Smoke/Common.ps1"
. "$RepoRoot/Scripts/Smoke/New-SEPMGroup/Tests.ps1"
