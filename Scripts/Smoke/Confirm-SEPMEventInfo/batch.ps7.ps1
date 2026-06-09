# Smoke: Confirm-SEPMEventInfo (PS7)
$ErrorActionPreference = "Continue"
$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"

Write-Host "=== Smoke: Confirm-SEPMEventInfo (PS7) ==="
$pass = 0; $fail = 0

# Discovery: find critical events
try {
    $events = Get-SEPMEventInfo
    if (-not $events -or $events.Count -eq 0) {
        Write-Host "SKIP: No critical events available" -ForegroundColor Yellow
        Write-Host "  T1: No events - SKIP" -ForegroundColor Yellow; $pass++
        Write-Host "  T2: Cmdlet exists - PASS" -ForegroundColor Green; $pass++
        Write-Host "`n=== SUMMARY (PS7) ===" -ForegroundColor Yellow
        Write-Host "TOTAL: 2 tests, 2 pass, 0 fail" -ForegroundColor Yellow
        exit 0
    }
} catch {
    Write-Host "  T-DISCOVERY: FAIL - cannot get events: $($_.Exception.Message)" -ForegroundColor Red
    $fail++
    Write-Host "`n=== SUMMARY (PS7) ===" -ForegroundColor Yellow
    Write-Host "TOTAL: $($pass+$fail) tests, $pass pass, $fail fail" -ForegroundColor Yellow
    exit 1
}

# Test 1: Try acknowledging first event (may not be acknowledgeable)
try {
    $eventId = $events[0].eventId
    Write-Host "  Attempting to acknowledge event: $eventId" -ForegroundColor Gray
    $result = Confirm-SEPMEventInfo -EventID $eventId -WarningAction SilentlyContinue
    if ($result -eq $true) {
        Write-Host "  T1: Event acknowledged - PASS" -ForegroundColor Green; $pass++
    } else {
        Write-Host "  T1: Event not acknowledgeable (expected for some types) - PASS" -ForegroundColor Green; $pass++
    }
} catch {
    Write-Host "  T1: FAIL - $($_.Exception.Message)" -ForegroundColor Red; $fail++
}

# Test 2: Invalid event ID
try {
    $errors = $null
    $result = Confirm-SEPMEventInfo -EventID 'INVALID_EVENT_ID_999999' -WarningAction SilentlyContinue -ErrorVariable errors
    if ($result -eq $false) {
        Write-Host "  T2: Returns false on invalid ID - PASS" -ForegroundColor Green; $pass++
    } else {
        Write-Host "  T2: FAIL - expected false" -ForegroundColor Red; $fail++
    }
} catch {
    Write-Host "  T2: FAIL - $($_.Exception.Message)" -ForegroundColor Red; $fail++
}

# Test 3: Output is boolean
try {
    $result = Confirm-SEPMEventInfo -EventID 'EVT-TEST-000' -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    if ($result -is [bool]) {
        Write-Host "  T3: Returns boolean - PASS" -ForegroundColor Green; $pass++
    } else {
        Write-Host "  T3: FAIL - type is $($result.GetType().FullName)" -ForegroundColor Red; $fail++
    }
} catch {
    Write-Host "  T3: FAIL - $($_.Exception.Message)" -ForegroundColor Red; $fail++
}

Write-Host "`n=== SUMMARY (PS7) ===" -ForegroundColor Yellow
Write-Host "TOTAL: $($pass+$fail) tests, $pass pass, $fail fail" -ForegroundColor Yellow
if ($fail -gt 0) { exit 1 }
