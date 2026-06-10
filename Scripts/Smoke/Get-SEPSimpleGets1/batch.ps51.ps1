# Smoke batch: simple GET cmdlets batch 1 (PS5.1)
# Covers: Get-SEPClientInfectedStatus, Get-SEPFileDetails, Get-SEPGUPList,
#         Get-SEPMCommandStatus, Get-SEPMDatabaseInfo, Get-SEPMEventInfo
# Usage: .\batch.ps51.ps1 (run on Windows VM)

$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"
. "$RepoRoot\Common-PS51.ps1"

Write-Host "=== Smoke: Simple GETs Batch 1 (PS5.1) ==="

# ── A1: Get-SEPClientInfectedStatus ──
Write-Host "--- A1 : Get-SEPClientInfectedStatus ---" -ForegroundColor Cyan
try {
    $r = Get-SEPClientInfectedStatus
    $asArr = @($r)
    if ($asArr.Count -ge 0) {
        Write-Host "  VERDICT: PASS (count: $($asArr.Count))" -ForegroundColor Green
    } else {
        Write-Host "  VERDICT: FAIL" -ForegroundColor Red
    }
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
}

# ── A2: Get-SEPClientInfectedStatus -Clean ──
Write-Host "--- A2 : Get-SEPClientInfectedStatus -Clean ---" -ForegroundColor Cyan
try {
    $r = Get-SEPClientInfectedStatus -Clean
    $asArr = @($r)
    if ($asArr.Count -ge 0) {
        Write-Host "  VERDICT: PASS (count: $($asArr.Count))" -ForegroundColor Green
    } else {
        Write-Host "  VERDICT: FAIL" -ForegroundColor Red
    }
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
}

# ── B1: Get-SEPGUPList ──
Write-Host "--- B1 : Get-SEPGUPList ---" -ForegroundColor Cyan
try {
    $r = Get-SEPGUPList
    if ($r -is [array]) {
        Write-Host "  VERDICT: PASS (count: $($r.Count))" -ForegroundColor Green
    } elseif ($null -eq $r) {
        Write-Host "  VERDICT: PASS (empty)" -ForegroundColor Green
    } else {
        Write-Host "  VERDICT: FAIL" -ForegroundColor Red
    }
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
}

# ── C1: Get-SEPMDatabaseInfo ──
Write-Host "--- C1 : Get-SEPMDatabaseInfo ---" -ForegroundColor Cyan
try {
    $r = Get-SEPMDatabaseInfo
    if ($r -ne $null -and $r.name -ne $null -and $r.database -ne $null) {
        Write-Host "  VERDICT: PASS (name: $($r.name), db: $($r.database))" -ForegroundColor Green
    } else {
        Write-Host "  VERDICT: FAIL" -ForegroundColor Red
    }
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
}

# ── D1: Get-SEPMEventInfo ──
Write-Host "--- D1 : Get-SEPMEventInfo ---" -ForegroundColor Cyan
try {
    $r = Get-SEPMEventInfo
    if ($r -is [array] -and $r.Count -gt 0 -and $r[0].eventId -ne $null) {
        $tn = $r[0].PSObject.TypeNames[0]
        Write-Host "  VERDICT: PASS (count: $($r.Count), type: $tn)" -ForegroundColor Green
    } else {
        Write-Host "  VERDICT: FAIL" -ForegroundColor Red
    }
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
}

# ── E1: Get-SEPMCommandStatus (discover command ID) ──
Write-Host "--- E1 : Get-SEPMCommandStatus ---" -ForegroundColor Cyan
try {
    $s = Initialize-SEPMSession
    $queue = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/command-queue?pageSize=50" -Session $s
    if ($queue.content -and $queue.content.Count -gt 0) {
        $cmdId = $queue.content[0].commandId
        if ($cmdId) {
            $r = Get-SEPMCommandStatus -Command_ID $cmdId
            if ($r -is [array] -and $r[0].computerName -ne $null) {
                Write-Host "  VERDICT: PASS (command: $cmdId, type: $($r[0].PSObject.TypeNames[0]))" -ForegroundColor Green
            } else {
                Write-Host "  VERDICT: FAIL" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "  SKIP: No commands in queue" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
}

# ── F1: Get-SEPFileDetails (discover file ID) ──
Write-Host "--- F1 : Get-SEPFileDetails ---" -ForegroundColor Cyan
try {
    $fileId = $null
    $knownId = "67C2C7AFAC1E00022E681989133418AF"
    try {
        $test = Get-SEPFileDetails -FileID $knownId
        if ($test.id) { $fileId = $knownId }
    } catch { }
    if (-not $fileId) {
        $s = Initialize-SEPMSession
        $queue = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/command-queue?pageSize=50" -Session $s
        foreach ($cmd in $queue.content) {
            if ($cmd.binaryFileId) { $fileId = $cmd.binaryFileId; break }
        }
    }
    if ($fileId) {
        $r = Get-SEPFileDetails -FileID $fileId
        if ($r -ne $null -and $r.id -ne $null -and $r.fileSize -ne $null) {
            Write-Host "  VERDICT: PASS (id: $($r.id), size: $($r.fileSize))" -ForegroundColor Green
        } else {
            Write-Host "  VERDICT: FAIL" -ForegroundColor Red
        }
    } else {
        Write-Host "  SKIP: No files in command queue" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== Smoke Complete: Simple GETs Batch 1 (PS5.1) ===" -ForegroundColor Yellow
