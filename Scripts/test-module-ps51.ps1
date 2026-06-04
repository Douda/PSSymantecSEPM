# Test PSSymantecSEPM on PS 5.1
# Run via: powershell -ExecutionPolicy Bypass -File C:\Users\douda\Desktop\Shared\test-module.ps1

$ErrorActionPreference = "Continue"
Write-Host "=== PS 5.1 Module Test ===" -ForegroundColor Cyan

Import-Module "C:\Users\douda\Desktop\Shared\PSSymantecSEPM\PSSymantecSEPM.psm1" -Force
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

Set-SepmConfiguration -ServerAddress 127.0.0.1 -Port 8446

$secpass = ConvertTo-SecureString "Aurelien1!" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential("admin", $secpass)
Set-SEPMAuthentication -Credentials $cred

$m = Get-Module PSSymantecSEPM
& $m { $script:SkipCert = $true }

Write-Host "Version:" -ForegroundColor Cyan
Get-SEPMVersion | Format-List

Write-Host "Groups:" -ForegroundColor Cyan
Get-SEPMGroups | Select-Object name -First 3 | Format-Table

Write-Host "Policies:" -ForegroundColor Cyan
$count = (Get-SEPMPoliciesSummary | Measure-Object).Count
Write-Host "$count policies found"

Write-Host "Client Status:" -ForegroundColor Cyan
Get-SEPClientStatus

Write-Host ""
Write-Host "=== PS 5.1 TEST PASSED ===" -ForegroundColor Green
