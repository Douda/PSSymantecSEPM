$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"

# PS5.1 transport prerequisites
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

# SEPM configuration
$cfg = "$env:APPDATA\PSSymantecSEPM\config.json"
New-Item -ItemType Directory (Split-Path $cfg) -Force | Out-Null
@{ port = 8446; ServerAddress = "localhost" } | ConvertTo-Json | Set-Content $cfg -Force

# Module import
$ModulePath = "$RepoRoot\PSSymantecSEPM\PSSymantecSEPM.psm1"
Import-Module $ModulePath -Force
$env:PSModulePath = "$RepoRoot;$env:PSModulePath"

$SmokeModule = Get-Module PSSymantecSEPM
& $SmokeModule { $script:SkipCert = $true }

# Shared infrastructure + tests
. "$RepoRoot\Scripts\Smoke\Common.ps1"
. "$RepoRoot\Scripts\Smoke\Get-SEPComputers\Tests.ps1"
