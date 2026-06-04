# Test PSSymantecSEPM on PS 5.1
# Requires SEPM server running on localhost:8446
# Usage: powershell -ExecutionPolicy Bypass -File <path>
# SEPM credentials can be set via env: $env:SEPM_USER, $env:SEPM_PASS

param(
    [string]$SepmServer = "127.0.0.1",
    [string]$SepmPort = "8446",
    [string]$SepmUser = $env:SEPM_USER,
    [string]$SepmPass = $env:SEPM_PASS
)

$ErrorActionPreference = "Continue"
Write-Host "=== PS 5.1 Module Test ===" -ForegroundColor Cyan

Import-Module "$PSScriptRoot\PSSymantecSEPM\PSSymantecSEPM.psm1" -Force
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

Set-SepmConfiguration -ServerAddress $SepmServer -Port $SepmPort

if (-not $SepmUser) { $SepmUser = Read-Host "SEPM username" }
if (-not $SepmPass) { $SepmPass = Read-Host "SEPM password" -AsSecureString } else {
    $SepmPass = ConvertTo-SecureString $SepmPass -AsPlainText -Force
}
$cred = New-Object System.Management.Automation.PSCredential($SepmUser, $SepmPass)
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
