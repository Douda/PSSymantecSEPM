<#
.SYNOPSIS
    PS5.1 entry point for Export-SEPMInventory smoke tests.

.DESCRIPTION
    Bootstraps the module and SEPM connection for PS 5.1 from the shared volume,
    then dot-sources Common.ps1 (auth + helpers) and Tests.ps1 (test cases).

    Usage (from host): python3 Scripts/invoke-winrm.py 'C:\Users\smokeuser\Desktop\Shared\smoke-export-inventory.ps1'
#>

$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"

# ── Bootstrap: import module, cert bypass, config, auth ──
. "$RepoRoot\Scripts\Smoke\Bootstrap.ps1"
Initialize-SmokeBootstrap -RepoRoot $RepoRoot

# ── Shared infrastructure + tests ──
. "$RepoRoot\Scripts\Smoke\Common.ps1"
. "$RepoRoot\Scripts\Smoke\Export-SEPMInventory\Tests.ps1"
