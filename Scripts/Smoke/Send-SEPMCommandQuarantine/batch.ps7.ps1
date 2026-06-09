# Smoke verification for Send-SEPMCommandQuarantine (PS7)
# Verifies the command dispatch path by sending commands to non-existent clients.
# The API returns validation errors, which confirms the dispatch was attempted.
$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"

Write-Host "=== Smoke: Send-SEPMCommandQuarantine (PS7) ==="

# ── Helper: smoke test for mutation cmdlets where API errors are expected ──
function TE {
    param($Id, $Label, [ScriptBlock]$Action)
    Write-Host "--- $Id : $Label ---" -ForegroundColor Cyan
    try {
        $result = & $Action
        if ($null -eq $result) {
            Write-Host "  VERDICT: FAIL (null response)" -ForegroundColor Red
            return "FAIL"
        }
        Write-Host "  VERDICT: PASS (API reached)" -ForegroundColor Green
        return "PASS"
    } catch {
        Write-Host "  VERDICT: FAIL (exception: $($_.Exception.Message))" -ForegroundColor Red
        return "FAIL"
    }
}

$results = @{}

$results.A1 = TE -Id "A1" -Label "Quarantine to non-existent computer" `
    -Action { Send-SEPMCommandQuarantine -ComputerName 'NonExistentPC_SmokeTest' }

$results.A2 = TE -Id "A2" -Label "Quarantine to non-existent group" `
    -Action { Send-SEPMCommandQuarantine -GroupName 'My Company\NonExistentSmokeGroup' }

$results.A3 = TE -Id "A3" -Label "Unquarantine (undo=true) to non-existent computer" `
    -Action { Send-SEPMCommandQuarantine -ComputerName 'NonExistentPC_SmokeTest' -Unquarantine }

# Summary
Write-Host "`n========== SUMMARY (PS7) ==========" -ForegroundColor Yellow
$pass = 0; $fail = 0
foreach ($k in $results.Keys | Sort-Object) {
    $v = $results[$k]
    if ($v -eq "PASS") { $pass++; Write-Host "  $k : PASS" -ForegroundColor Green }
    else { $fail++; Write-Host "  $k : FAIL" -ForegroundColor Red }
}
Write-Host "TOTAL: $($pass+$fail) tests, $pass pass, $fail fail" -ForegroundColor Yellow
