<#
.SYNOPSIS
    Shared smoke tests for Confirm-SEPMEventInfo.

.DESCRIPTION
    Dot-sourced by run.ps7.ps1 and run.ps51.ps1 after Common.ps1.
    Covers: acknowledge event, invalid event returns false, returns boolean.
#>

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

Write-Summary -Results $results -Label "Confirm-SEPMEventInfo Smoke Tests"
