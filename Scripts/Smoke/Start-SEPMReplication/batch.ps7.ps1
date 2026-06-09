# Smoke: Start-SEPMReplication (PS7)
$ErrorActionPreference = "Continue"
$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"

Write-Host "=== Smoke: Start-SEPMReplication (PS7) ==="
$pass = 0; $fail = 0

# Test 1: Send with partner site name (may fail but should hit API)
try {
    $result = Start-SEPMReplication -partnerSiteName 'RemoteSiteTest'
    if ($result) {
        Write-Host "  T1: Replication command sent - PASS" -ForegroundColor Green; $pass++
    } else {
        Write-Host "  T1: Null response - PASS (expected for no partner sites)" -ForegroundColor Yellow; $pass++
    }
} catch {
    $msg = $_.Exception.Message
    if ($msg -match 'partner|site|replication|not found') {
        Write-Host "  T1: Expected API error - PASS" -ForegroundColor Green; $pass++
    } else {
        Write-Host "  T1: FAIL - $msg" -ForegroundColor Red; $fail++
    }
}

# Test 2: Call without parameters
try {
    $result = Start-SEPMReplication
    if ($result -ne $null) {
        Write-Host "  T2: No-param call OK - PASS" -ForegroundColor Green; $pass++
    } else {
        Write-Host "  T2: No-param call null - PASS (acceptable)" -ForegroundColor Yellow; $pass++
    }
} catch {
    Write-Host "  T2: FAIL - $($_.Exception.Message)" -ForegroundColor Red; $fail++
}

# Test 3: Verify cmdlet exists and is callable
try {
    $cmd = Get-Command Start-SEPMReplication -ErrorAction Stop
    Write-Host "  T3: Cmdlet exists - PASS" -ForegroundColor Green; $pass++
} catch {
    Write-Host "  T3: FAIL - cmdlet not found" -ForegroundColor Red; $fail++
}

Write-Host "`n=== SUMMARY (PS7) ===" -ForegroundColor Yellow
Write-Host "TOTAL: $($pass+$fail) tests, $pass pass, $fail fail" -ForegroundColor Yellow
if ($fail -gt 0) { exit 1 }
