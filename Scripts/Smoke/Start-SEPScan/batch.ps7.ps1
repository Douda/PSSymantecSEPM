# Smoke: Start-SEPScan (PS7)
$ErrorActionPreference = "Continue"
$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"

Write-Host "=== Smoke: Start-SEPScan (PS7) ==="
$pass = 0; $fail = 0

# Discovery: find a computer
$computers = @(Get-SEPComputers -ComputerName 'WIN-P093KPK2K7Q')
if ($computers.Count -eq 0) {
    Write-Host "SKIP: No computers found" -ForegroundColor Yellow
    exit 0
}
$computerName = $computers[0].computerName
Write-Host "Using computer: $computerName" -ForegroundColor Gray

# Test 1: Send ActiveScan
try {
    $result = Start-SEPScan -ComputerName $computerName -ActiveScan
    if ($result) {
        Write-Host "  T1: ActiveScan command sent - PASS" -ForegroundColor Green; $pass++
    } else {
        Write-Host "  T1: FAIL - null response" -ForegroundColor Red; $fail++
    }
} catch {
    Write-Host "  T1: FAIL - $($_.Exception.Message)" -ForegroundColor Red; $fail++
}

# Test 2: Send FullScan
try {
    $result = Start-SEPScan -ComputerName $computerName -FullScan
    if ($result) {
        Write-Host "  T2: FullScan command sent - PASS" -ForegroundColor Green; $pass++
    } else {
        Write-Host "  T2: FAIL - null response" -ForegroundColor Red; $fail++
    }
} catch {
    Write-Host "  T2: FAIL - $($_.Exception.Message)" -ForegroundColor Red; $fail++
}

# Test 3: Pipeline input
try {
    $result = $computerName | Start-SEPScan -ActiveScan
    if ($result) {
        Write-Host "  T3: Pipeline input - PASS" -ForegroundColor Green; $pass++
    } else {
        Write-Host "  T3: FAIL" -ForegroundColor Red; $fail++
    }
} catch {
    Write-Host "  T3: FAIL - $($_.Exception.Message)" -ForegroundColor Red; $fail++
}

# Test 4: Invalid computer name
try {
    $errors = $null
    $result = Start-SEPScan -ComputerName 'NonExistentComputer12345' -ActiveScan -ErrorVariable errors -ErrorAction SilentlyContinue
    # Should not throw but may return empty or error
    Write-Host "  T4: Invalid computer handled - PASS" -ForegroundColor Green; $pass++
} catch {
    Write-Host "  T4: FAIL - $($_.Exception.Message)" -ForegroundColor Red; $fail++
}

# Test 5: Output non-null
try {
    $result = Start-SEPScan -ComputerName $computerName -ActiveScan
    if ($result -ne $null) {
        Write-Host "  T5: Non-null output - PASS" -ForegroundColor Green; $pass++
    } else {
        Write-Host "  T5: FAIL" -ForegroundColor Red; $fail++
    }
} catch {
    Write-Host "  T5: FAIL - $($_.Exception.Message)" -ForegroundColor Red; $fail++
}

Write-Host "`n=== SUMMARY (PS7) ===" -ForegroundColor Yellow
Write-Host "TOTAL: $($pass+$fail) tests, $pass pass, $fail fail" -ForegroundColor Yellow
if ($fail -gt 0) { exit 1 }
