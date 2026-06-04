<#
.SYNOPSIS
    One-shot Windows VM setup for PSSymantecSEPM development.
    Enables WinRM, configures firewall, certs, and remote access.
    Run ONCE as Administrator on a fresh Windows VM.
    Run from: C:\Users\<user>\Desktop\Shared\setup-vm.ps1
#>

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"
$vmUser = "douda"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  PSSymantecSEPM VM Setup" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# ── 1. Enable WinRM ──
Write-Host "[1/5] Enabling WinRM..." -ForegroundColor Yellow
Enable-PSRemoting -Force -SkipNetworkProfileCheck
Set-Service -Name WinRM -StartupType Automatic
Write-Host "  Done." -ForegroundColor Green

# ── 2. Configure WinRM auth + firewall ──
Write-Host "[2/5] Configuring WinRM auth and firewall..." -ForegroundColor Yellow
Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $true -Force
Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $true -Force
Set-Item -Path WSMan:\localhost\MaxEnvelopeSizekb -Value 4096
Set-Item -Path WSMan:\localhost\MaxTimeoutms -Value 180000

New-NetFirewallRule -Name "WinRM HTTP" -Protocol TCP -LocalPort 5985 -Direction Inbound -Action Allow -ErrorAction SilentlyContinue | Out-Null
New-NetFirewallRule -Name "WinRM HTTPS" -Protocol TCP -LocalPort 5986 -Direction Inbound -Action Allow -ErrorAction SilentlyContinue | Out-Null
Write-Host "  Done." -ForegroundColor Green

# ── 3. Add user to WinRM groups ──
Write-Host "[3/5] Adding $vmUser to remote management groups..." -ForegroundColor Yellow
try { Add-LocalGroupMember -Group "Remote Management Users" -Member $vmUser -ErrorAction Stop } catch { Write-Host "  (already in group or skipped)" -ForegroundColor Gray }
try { Add-LocalGroupMember -Group "Administrators" -Member $vmUser -ErrorAction Stop } catch { Write-Host "  (already in group or skipped)" -ForegroundColor Gray }
Write-Host "  Done." -ForegroundColor Green

# ── 4. Create HTTPS listener with self-signed cert ──
Write-Host "[4/5] Creating WinRM HTTPS listener..." -ForegroundColor Yellow
$hostname = $env:COMPUTERNAME
$cert = New-SelfSignedCertificate `
    -DnsName @($hostname, "localhost") `
    -CertStoreLocation "Cert:\LocalMachine\My" `
    -KeyAlgorithm RSA -KeyLength 2048 `
    -Type SSLServerAuthentication `
    -ErrorAction Stop
New-Item -Path WSMan:\localhost\Listener -Transport HTTPS -Address * -CertificateThumbprint $cert.Thumbprint -Force | Out-Null
Write-Host "  HTTPS listener created (thumbprint: $($cert.Thumbprint))" -ForegroundColor Green

# ── 5. Restart WinRM ──
Write-Host "[5/5] Restarting WinRM..." -ForegroundColor Yellow
Restart-Service WinRM -Force
Start-Sleep -Seconds 2
Write-Host "  Done." -ForegroundColor Green

# ── Verify ──
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Verification" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$svc = Get-Service WinRM
Write-Host "WinRM Service: $($svc.Status)"
Write-Host "Listeners: $(winrm enumerate winrm/config/listener | Select-String Transport | ForEach-Object { $_.Line.Trim() })"

Write-Host ""
Write-Host "=== SETUP COMPLETE ===" -ForegroundColor Green
Write-Host ""
Write-Host "Next: install Symantec SEPM, then from devcontainer:" -ForegroundColor White
Write-Host "  python3 Scripts/invoke-winrm.py 'C:\...\Shared\test-module.ps1'" -ForegroundColor Gray
