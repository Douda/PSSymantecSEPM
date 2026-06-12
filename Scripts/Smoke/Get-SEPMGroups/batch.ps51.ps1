$ErrorActionPreference = "Continue"

# Import and configure the module
$modulePath = "C:\Users\smokeuser\Desktop\Shared\PSSymantecSEPM\PSSymantecSEPM.psm1"
Import-Module -Name $modulePath -Force -Global
Set-SepmConfiguration -ServerAddress '127.0.0.1' -Port 8446

# Bypass certificate check for PS5.1
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"
. "$RepoRoot\Common-PS51.ps1"

Write-Host "=== Smoke: Get-SEPMGroups (PS5.1) ==="

$results = @{}

$results.A1 = T "A1" "returns groups from the API" `
    { Get-SEPMGroups } `
    { param($r) $r -ne $null -and @($r).Count -gt 0 }

$results.A2 = T "A2" "each group has id, name, and fullPathName" `
    { Get-SEPMGroups } `
    { param($r) @($r)[0].id -ne $null -and @($r)[0].name -ne $null -and @($r)[0].fullPathName -ne $null }

$results.A3 = T "A3" "returns collection (not scalar) when single element" `
    { Get-SEPMGroups } `
    { param($r) $r.Count -ge 1 -and (@($r).Count -eq $r.Count) }

Write-Summary -Results $results -Label "Get-SEPMGroups Smoke"
