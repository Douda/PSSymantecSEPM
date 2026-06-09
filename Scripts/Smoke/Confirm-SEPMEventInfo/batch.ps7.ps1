# Smoke: Confirm-SEPMEventInfo (PS7)
# Usage: pwsh -NoProfile -File Scripts/Smoke/Confirm-SEPMEventInfo/batch.ps7.ps1

$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"

Write-Host "=== Smoke: Confirm-SEPMEventInfo (PS7) ===" -ForegroundColor Yellow

$results = @{}

# ── Discovery: find critical events ──
$events = Get-SEPMEventInfo -ErrorAction SilentlyContinue
if (-not $events -or $events.Count -eq 0) {
    $results.A1 = Skip "A1" "Acknowledge event" "No critical events available"
    $results.A2 = Skip "A2" "Invalid event returns false" "No events for context"
    $results.A3 = Skip "A3" "Returns boolean" "No events for context"
} else {
    $eventId = $events[0].eventId

    # ── A1: Acknowledge event (may succeed or return false for non-acknowledgeable) ──
    $results.A1 = T "A1" "Acknowledge event" `
        { Confirm-SEPMEventInfo -EventID $eventId -WarningAction SilentlyContinue } `
        { param($r) $r -is [bool] }

    # ── A2: Invalid event ID returns false ──
    $results.A2 = T "A2" "Invalid event returns false" `
        { Confirm-SEPMEventInfo -EventID 'INVALID_EVENT_ID_999999' -WarningAction SilentlyContinue } `
        { param($r) $r -eq $false }

    # ── A3: Returns boolean ──
    $results.A3 = T "A3" "Returns boolean" `
        { Confirm-SEPMEventInfo -EventID 'EVT-TEST-000' -WarningAction SilentlyContinue -ErrorAction SilentlyContinue } `
        { param($r) $r -is [bool] }
}

# === Summary ===
Write-Host "`n========== SUMMARY (PS7) ==========" -ForegroundColor Yellow
$pass = 0; $fail = 0; $skip = 0
foreach ($k in $results.Keys | Sort-Object) {
    $v = $results[$k]
    if ($v -eq "PASS") { $pass++; Write-Host "  $k : PASS" -ForegroundColor Green }
    elseif ($v -eq "SKIP") { $skip++; Write-Host "  $k : SKIP" -ForegroundColor Yellow }
    else { $fail++; Write-Host "  $k : FAIL" -ForegroundColor Red }
}
Write-Host "TOTAL: $($pass+$fail+$skip) tests, $pass pass, $fail fail, $skip skip" -ForegroundColor Yellow

if ($fail -gt 0) { exit 1 }
