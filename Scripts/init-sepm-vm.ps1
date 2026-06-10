<#
.SYNOPSIS
    Idempotent SEPM VM initialization — config + credentials.
    Runs ON the Windows VM (via WinRM), not in the devcontainer.

.DESCRIPTION
    Creates SEPM config and credentials on the VM so the module can
    authenticate non-interactively. Safe to run multiple times.

.PARAMETER SepmUser
    SEPM admin username (default: admin)

.PARAMETER SepmPass
    SEPM admin password (default: Aurelien1!)

.PARAMETER SepmHost
    SEPM server address from the VM's perspective (default: localhost)

.PARAMETER SepmPort
    SEPM API port (default: 8446)

.EXAMPLE
    # Run via WinRM with defaults
    .\init-sepm-vm.ps1

.EXAMPLE
    # Custom credentials
    .\init-sepm-vm.ps1 -SepmUser "admin" -SepmPass "MyPass123!" -SepmHost "192.168.1.10" -SepmPort 8446
#>

[CmdletBinding()]
param(
    [string]$SepmUser = "admin",
    [string]$SepmPass = "MyComplexPassword1!",
    [string]$SepmHost = "localhost",
    [int]$SepmPort = 8446
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$configDir = Join-Path $env:APPDATA "PSSymantecSEPM"
$configFile = Join-Path $configDir "config.json"
$credsFile = Join-Path $configDir "creds.xml"

# ── 1. Config file ──
Write-Host "[init-sepm-vm] Writing SEPM config..." -ForegroundColor Cyan
New-Item -ItemType Directory $configDir -Force | Out-Null
@{ ServerAddress = $SepmHost; port = $SepmPort } | ConvertTo-Json | Set-Content $configFile -Force
Write-Host "  config.json → $configFile" -ForegroundColor Green

# ── 2. Credentials file (Export-Clixml uses DPAPI — machine+user scoped) ──
Write-Host "[init-sepm-vm] Writing SEPM credentials..." -ForegroundColor Cyan
$secpass = ConvertTo-SecureString $SepmPass -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($SepmUser, $secpass)
$cred | Export-Clixml -Path $credsFile -Force
Write-Host "  creds.xml → $credsFile" -ForegroundColor Green

# ── 3. Verify module can import creds ──
Write-Host "[init-sepm-vm] Verifying credentials..." -ForegroundColor Cyan
try {
    $imported = Import-Clixml -Path $credsFile
    if ($imported.UserName -eq $SepmUser) {
        Write-Host "  OK: credentials valid for user '$($imported.UserName)'" -ForegroundColor Green
    } else {
        Write-Error "  FAIL: imported user '$($imported.UserName)' != '$SepmUser'"
        exit 1
    }
} catch {
    Write-Error "  FAIL: could not import creds.xml: $_"
    exit 1
}

Write-Host "[init-sepm-vm] Done." -ForegroundColor Green
