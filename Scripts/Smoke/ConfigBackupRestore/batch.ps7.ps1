$ErrorActionPreference = "Continue"
$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"

Write-Host "=== Smoke: Config Backup/Restore (PS7) ==="

$results = @{}

# ── Set-SepmConfiguration ──
$results.A1 = T "A1" "Set-SepmConfiguration creates config file" `
    { Set-SepmConfiguration -ServerAddress 'smoke-test' -Port 8080; Get-Content "$HOME/.config/PSSymantecSEPM/config.json" -Raw } `
    { param($r) $r -match 'smoke-test' }

# ── Read-SepmConfiguration ──
$results.A2 = T "A2" "Read-SepmConfiguration returns persisted config" `
    {
        $mod = Get-Module PSSymantecSEPM
        & $mod { Read-SepmConfiguration -Path $script:configurationFilePath }
    } `
    { param($r) $r.ServerAddress -eq 'smoke-test' }

# ── Backup-SEPMConfiguration ──
$backupFile = Join-Path ([System.IO.Path]::GetTempPath()) 'smoke-config-backup.json'
$results.B1 = T "B1" "Backup-SEPMConfiguration exports to file" `
    { Backup-SEPMConfiguration -Path $backupFile -Force; Test-Path $backupFile } `
    { param($r) $r -eq $true }

$results.B2 = T "B2" "Backup-SEPMConfiguration file contains valid JSON" `
    { Get-Content $backupFile -Raw | ConvertFrom-Json } `
    { param($r) $r.ServerAddress -eq 'smoke-test' }

# ── Restore-SEPMConfiguration ──
$results.R1 = T "R1" "Restore-SEPMConfiguration restores from backup" `
    {
        # Modify config first
        Set-SepmConfiguration -ServerAddress 'before-restore' -Port 9999
        Restore-SEPMConfiguration -Path $backupFile
        $mod = Get-Module PSSymantecSEPM
        & $mod { $script:configuration.ServerAddress }
    } `
    { param($r) $r -eq 'smoke-test' }

# ── Reset-SepmConfiguration ──
$results.R2 = T "R2" "Reset-SepmConfiguration deletes config file" `
    {
        Set-SepmConfiguration -ServerAddress 'will-be-deleted' -Port 8446
        Reset-SEPMConfiguration
        $mod = Get-Module PSSymantecSEPM
        & $mod { Test-Path -Path $script:configurationFilePath -PathType Leaf }
    } `
    { param($r) $r -eq $false }

# ── ConvertTo-FlatObject ──
$results.F1 = T "F1" "ConvertTo-FlatObject flattens nested object" `
    {
        $obj = [PSCustomObject]@{ Outer = [PSCustomObject]@{ Inner = 'value' } }
        $obj | ConvertTo-FlatObject
    } `
    { param($r) $r.'Outer.Inner' -eq 'value' }

# ── Backup/restore credentials ──
$creds = New-Object System.Management.Automation.PSCredential 'SmokeUser',
    (ConvertTo-SecureString -String 'SmokePass' -AsPlainText -Force)
Set-SEPMAuthentication -Credentials $creds

$credBackup = Join-Path ([System.IO.Path]::GetTempPath()) 'smoke-cred-backup.xml'
$results.C1 = T "C1" "Backup-SEPMAuthentication exports credentials" `
    { Backup-SEPMAuthentication -Path $credBackup -Credentials -Force; Test-Path $credBackup } `
    { param($r) $r -eq $true }

$results.C2 = T "C2" "Restore-SEPMAuthentication restores credentials" `
    {
        $newCreds = New-Object System.Management.Automation.PSCredential 'OtherUser',
            (ConvertTo-SecureString -String 'OtherPass' -AsPlainText -Force)
        Set-SEPMAuthentication -Credentials $newCreds
        Restore-SEPMAuthentication -Path $credBackup -Credential
        $mod = Get-Module PSSymantecSEPM
        & $mod { $script:Credential.UserName }
    } `
    { param($r) $r -eq 'SmokeUser' }

# ── Restore original SEPM config ──
Set-SepmConfiguration -ServerAddress 'localhost' -Port 8446

Remove-Item -Path $backupFile, $credBackup -Force -ErrorAction SilentlyContinue

# ── Final tally ──
$pass = ($results.Values | Where-Object { $_ -eq 'PASS' }).Count
$fail = ($results.Values | Where-Object { $_ -eq 'FAIL' }).Count
$skip = ($results.Values | Where-Object { $_ -eq 'SKIP' }).Count
Write-Host "`n=== Results: $pass PASS, $fail FAIL, $skip SKIP ===" -ForegroundColor $(if ($fail -gt 0) { 'Red' } else { 'Green' })

if ($fail -gt 0) {
    Write-Error "Smoke tests failed: $fail failure(s)"
    exit 1
}
