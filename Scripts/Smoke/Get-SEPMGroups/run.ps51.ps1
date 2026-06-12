<#
.SYNOPSIS
    PS5.1 entry point for Get-SEPMGroups smoke tests.

.DESCRIPTION
    Bootstraps the module and SEPM connection for PS 5.1 on the Windows VM,
    then dot-sources Common.ps1 (auth + helpers) and Tests.ps1 (test cases).

    Deploy with UTF-8 BOM to the Windows VM before running:
      pwsh -NoProfile -c "...WriteAllText('/home/douda/Windows/...', ..., UTF8+BOM)"

    Usage: . "$RepoRoot\Scripts\Smoke\Get-SEPMGroups\run.ps51.ps1"
#>

$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"

# -- PS5.1 transport prerequisites --
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

# -- SEPM configuration (PS5.1 uses $env:APPDATA) --
$cfg = "$env:APPDATA\PSSymantecSEPM\config.json"
New-Item -ItemType Directory (Split-Path $cfg) -Force | Out-Null
@{ port = 8446; ServerAddress = "localhost" } | ConvertTo-Json | Set-Content $cfg -Force

# -- Module import --
$ModulePath = "$RepoRoot\PSSymantecSEPM\PSSymantecSEPM.psm1"
Import-Module $ModulePath -Force
$env:PSModulePath = "$RepoRoot;$env:PSModulePath"

$SmokeModule = Get-Module PSSymantecSEPM
& $SmokeModule { $script:SkipCert = $true }

# -- Shared infrastructure + tests --
. "$RepoRoot\Scripts\Smoke\Common.ps1"
. "$RepoRoot\Scripts\Smoke\Get-SEPMGroups\Tests.ps1"
