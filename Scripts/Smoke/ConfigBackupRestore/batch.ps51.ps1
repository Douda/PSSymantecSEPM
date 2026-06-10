$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"
. "$RepoRoot\Common-PS51.ps1"

Write-Host "=== Smoke: Config Backup/Restore (PS5.1) ==="

$results = @{}
$tempDir = [System.IO.Path]::GetTempPath()

# ── Set-SepmConfiguration ──
try {
    Set-SepmConfiguration -ServerAddress 'smoke-test' -Port 8080
    $content = Get-Content "$env:APPDATA\PSSymantecSEPM\config.json" -Raw
    if ($content -match 'smoke-test') {
        Write-Host "  A1 : Set-SepmConfiguration creates config file : PASS" -ForegroundColor Green
        $results.A1 = "PASS"
    } else {
        Write-Host "  A1 : Set-SepmConfiguration creates config file : FAIL" -ForegroundColor Red
        $results.A1 = "FAIL"
    }
} catch {
    Write-Host "  A1 : ERROR: $_" -ForegroundColor Red
    $results.A1 = "FAIL"
}

# ── Backup-SEPMConfiguration ──
$backupFile = Join-Path $tempDir 'smoke-config-backup.json'
try {
    Backup-SEPMConfiguration -Path $backupFile -Force
    if (Test-Path $backupFile) {
        Write-Host "  B1 : Backup-SEPMConfiguration exports to file : PASS" -ForegroundColor Green
        $results.B1 = "PASS"
    } else {
        Write-Host "  B1 : Backup-SEPMConfiguration exports to file : FAIL" -ForegroundColor Red
        $results.B1 = "FAIL"
    }
} catch {
    Write-Host "  B1 : ERROR: $_" -ForegroundColor Red
    $results.B1 = "FAIL"
}

# ── Restore-SEPMConfiguration ──
try {
    Set-SepmConfiguration -ServerAddress 'before-restore' -Port 9999
    Restore-SEPMConfiguration -Path $backupFile
    $mod = Get-Module PSSymantecSEPM -ErrorAction Stop
    $serverAddr = & $mod { $script:configuration.ServerAddress }
    if ($serverAddr -eq 'smoke-test') {
        Write-Host "  R1 : Restore-SEPMConfiguration restores from backup : PASS" -ForegroundColor Green
        $results.R1 = "PASS"
    } else {
        Write-Host "  R1 : Got '$serverAddr', expected 'smoke-test' : FAIL" -ForegroundColor Red
        $results.R1 = "FAIL"
    }
} catch {
    Write-Host "  R1 : ERROR: $_" -ForegroundColor Red
    $results.R1 = "FAIL"
}

# ── Reset-SepmConfiguration ──
try {
    Set-SepmConfiguration -ServerAddress 'will-be-deleted' -Port 8446
    Reset-SEPMConfiguration
    $mod = Get-Module PSSymantecSEPM -ErrorAction Stop
    $exists = & $mod { Test-Path -Path $script:configurationFilePath -PathType Leaf }
    if (-not $exists) {
        Write-Host "  R2 : Reset-SepmConfiguration deletes config file : PASS" -ForegroundColor Green
        $results.R2 = "PASS"
    } else {
        Write-Host "  R2 : Reset-SepmConfiguration deletes config file : FAIL" -ForegroundColor Red
        $results.R2 = "FAIL"
    }
} catch {
    Write-Host "  R2 : ERROR: $_" -ForegroundColor Red
    $results.R2 = "FAIL"
}

# ── ConvertTo-FlatObject ──
try {
    $obj = New-Object PSObject -Property @{ Outer = (New-Object PSObject -Property @{ Inner = 'value' }) }
    $flat = $obj | ConvertTo-FlatObject
    if ($flat.'Outer.Inner' -eq 'value') {
        Write-Host "  F1 : ConvertTo-FlatObject flattens nested object : PASS" -ForegroundColor Green
        $results.F1 = "PASS"
    } else {
        Write-Host "  F1 : ConvertTo-FlatObject flattens nested object : FAIL" -ForegroundColor Red
        $results.F1 = "FAIL"
    }
} catch {
    Write-Host "  F1 : ERROR: $_" -ForegroundColor Red
    $results.F1 = "FAIL"
}

# ── Restore original SEPM config ──
try {
    Set-SepmConfiguration -ServerAddress 'localhost' -Port 8446
} catch {
    Write-Host "  WARN: Could not restore SEPM config: $_"
}

Remove-Item -Path $backupFile -Force -ErrorAction SilentlyContinue

# ── Final tally ──
$pass = ($results.Values | Where-Object { $_ -eq 'PASS' }).Count
$fail = ($results.Values | Where-Object { $_ -eq 'FAIL' }).Count
Write-Host "`n=== Results: $pass PASS, $fail FAIL ==="

if ($fail -gt 0) {
    Write-Error "Smoke tests failed: $fail failure(s)"
    exit 1
}
