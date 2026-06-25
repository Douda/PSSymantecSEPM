<#
.SYNOPSIS
    PS5.1 entry point for Get-SEPClientInfectedStatus smoke tests.

.DESCRIPTION
    Bootstraps the module and SEPM connection for PS 5.1 on the Windows VM,
    then dot-sources Common.ps1 and Tests.ps1.

    Deploy with UTF-8 BOM to the Windows VM before running:
      pwsh -NoProfile -c "...WriteAllText('/home/douda/Windows/...', ..., UTF8+BOM)"

    Usage: . "$RepoRoot\PSSymantecSEPM\Smoke\Get-SEPClientInfectedStatus\run.ps51.ps1"
#>

$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"

# ── Bootstrap: import module, cert bypass, config, auth ──
. "$RepoRoot\Scripts\Smoke\Bootstrap.ps1"
Initialize-SmokeBootstrap -RepoRoot $RepoRoot

# ── Shared infrastructure + tests ──
. "$RepoRoot\Scripts\Smoke\Common.ps1"
. "$RepoRoot\Scripts\Smoke\Get-SEPClientInfectedStatus\Tests.ps1"
