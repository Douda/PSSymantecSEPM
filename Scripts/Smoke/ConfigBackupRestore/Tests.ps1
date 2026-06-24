<#
.SYNOPSIS
    Shared smoke tests for Config Backup/Restore cmdlets.

.DESCRIPTION
    Dot-sourced by run.ps7.ps1 and run.ps51.ps1 after Common.ps1.
    Covers: Set-SEPMConfiguration, Read-SepmConfiguration,
            Backup-SEPMConfiguration, Restore-SEPMConfiguration,
            Reset-SEPMConfiguration, ConvertTo-SEPMFlatObject,
            Backup/Restore-SEPMAuthentication, and cleanup.
    Restores original SEPM config at end.
#>

$results = @{}
$tempDir = [System.IO.Path]::GetTempPath()

# ── A1: Set-SEPMConfiguration creates config file ──
$results.A1 = T "A1" "Set-SEPMConfiguration creates config file" `
    {
        Set-SEPMConfiguration -ServerAddress 'smoke-test' -Port 8080
        $mod = Get-Module PSSymantecSEPM
        & $mod { Get-Content $script:configurationFilePath -Raw }
    } `
    { param($r) $r -match 'smoke-test' }

# ── A2: Read-SepmConfiguration returns persisted config ──
$results.A2 = T "A2" "Read-SepmConfiguration returns persisted config" `
    {
        $mod = Get-Module PSSymantecSEPM
        & $mod { Read-SepmConfiguration -Path $script:configurationFilePath }
    } `
    { param($r) $r.ServerAddress -eq 'smoke-test' }

# ── B1: Backup-SEPMConfiguration exports to file ──
$backupFile = Join-Path $tempDir 'smoke-config-backup.json'
$results.B1 = T "B1" "Backup-SEPMConfiguration exports to file" `
    { Backup-SEPMConfiguration -Path $backupFile -Force; Test-Path $backupFile } `
    { param($r) $r -eq $true }

# ── B2: Backup-SEPMConfiguration file contains valid JSON ──
$results.B2 = T "B2" "Backup-SEPMConfiguration file has valid JSON" `
    { Get-Content $backupFile -Raw | ConvertFrom-Json } `
    { param($r) $r.ServerAddress -eq 'smoke-test' }

# ── R1: Restore-SEPMConfiguration restores from backup ──
$results.R1 = T "R1" "Restore-SEPMConfiguration restores from backup" `
    {
        Set-SEPMConfiguration -ServerAddress 'before-restore' -Port 9999
        Restore-SEPMConfiguration -Path $backupFile
        $mod = Get-Module PSSymantecSEPM
        & $mod { $script:configuration.ServerAddress }
    } `
    { param($r) $r -eq 'smoke-test' }

# ── R2: Reset-SEPMConfiguration deletes config file ──
$results.R2 = T "R2" "Reset-SEPMConfiguration deletes config file" `
    {
        Set-SEPMConfiguration -ServerAddress 'will-be-deleted' -Port 8446
        Reset-SEPMConfiguration
        $mod = Get-Module PSSymantecSEPM
        & $mod { Test-Path -Path $script:configurationFilePath -PathType Leaf }
    } `
    { param($r) $r -eq $false }

# ── F1: ConvertTo-SEPMFlatObject flattens nested object ──
$results.F1 = T "F1" "ConvertTo-SEPMFlatObject flattens nested object" `
    {
        $obj = New-Object PSObject -Property @{ Outer = (New-Object PSObject -Property @{ Inner = 'value' }) }
        $obj | ConvertTo-SEPMFlatObject
    } `
    { param($r) $r.'Outer.Inner' -eq 'value' }

# ── C1: Backup-SEPMAuthentication exports credentials ──
$creds = New-Object System.Management.Automation.PSCredential 'SmokeUser',
    (ConvertTo-SecureString -String 'SmokePass' -AsPlainText -Force)
Set-SEPMAuthentication -Credentials $creds

$credBackup = Join-Path $tempDir 'smoke-cred-backup.xml'
$results.C1 = T "C1" "Backup-SEPMAuthentication exports credentials" `
    { Backup-SEPMAuthentication -Path $credBackup -Credentials -Force; Test-Path $credBackup } `
    { param($r) $r -eq $true }

# ── C2: Restore-SEPMAuthentication restores credentials ──
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
Set-SEPMConfiguration -ServerAddress 'localhost' -Port 8446

# ── Cleanup temp files ──
Remove-Item -Path $backupFile, $credBackup -Force -ErrorAction SilentlyContinue

# ── Summary ──
Write-Summary -Results $results -Label "Config Backup/Restore"
