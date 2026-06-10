$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"
. "$RepoRoot\Common-PS51.ps1"

Write-Host "=== Smoke: Confirm-SEPMEventInfo (PS5.1) ===" -ForegroundColor Yellow

$results = @{}

$events = Get-SEPMEventInfo -ErrorAction SilentlyContinue
if (-not $events -or $events.Count -eq 0) {
    $results.A1 = Skip "A1" "Acknowledge event" "No critical events available"
    $results.A2 = Skip "A2" "Invalid event returns false" "No events for context"
    $results.A3 = Skip "A3" "Returns boolean" "No events for context"
} else {
    $eventId = $events[0].eventId

    $results.A1 = T "A1" "Acknowledge event" `
        { Confirm-SEPMEventInfo -EventID $eventId -WarningAction SilentlyContinue } `
        { param($r) $r -is [bool] }

    $results.A2 = T "A2" "Invalid event returns false" `
        { Confirm-SEPMEventInfo -EventID 'INVALID_EVENT_ID_999999' -WarningAction SilentlyContinue } `
        { param($r) $r -eq $false }

    $results.A3 = T "A3" "Returns boolean" `
        { Confirm-SEPMEventInfo -EventID 'EVT-TEST-000' -WarningAction SilentlyContinue -ErrorAction SilentlyContinue } `
        { param($r) $r -is [bool] }
}

$pass = 0; $fail = 0; $skip = 0
foreach ($k in $results.Keys | Sort-Object) {
    $v = $results[$k]
    if ($v -eq "PASS") { $pass++; Write-Host "  $k : PASS" -ForegroundColor Green }
    elseif ($v -eq "SKIP") { $skip++; Write-Host "  $k : SKIP" -ForegroundColor Yellow }
    else { $fail++; Write-Host "  $k : FAIL" -ForegroundColor Red }
}
Write-Host "TOTAL: $($pass+$fail+$skip) tests, $pass pass, $fail fail, $skip skip" -ForegroundColor Yellow

if ($fail -gt 0) { Write-Error "Smoke tests failed: $fail failure(s)"; exit 1 }
