<#
.SYNOPSIS
    PS5.1 entry point for Seed-TDADPolicies smoke tests.

.DESCRIPTION
    Bootstraps the module and SEPM connection for PS 5.1 on the Windows VM,
    then dot-sources Common.ps1 (auth + helpers) and Tests.ps1 (test cases).

    Deploy with UTF-8 BOM to the Windows VM before running:
      pwsh -NoProfile -c "...WriteAllText('/home/douda/Windows/...', ..., UTF8+BOM)"

    Usage: . "$RepoRoot\Scripts\Smoke\Seed-TDADPolicies\run.ps51.ps1"
#>

$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"

# ── Bootstrap: import module, cert bypass, config, auth ──
. "$RepoRoot\Scripts\Smoke\Bootstrap.ps1"
Initialize-SmokeBootstrap -RepoRoot $RepoRoot

# ── Shared infrastructure + tests ──
. "$RepoRoot\Scripts\Smoke\Common.ps1"
. "$RepoRoot\Scripts\Smoke\Seed-TDADPolicies\Tests.ps1"
