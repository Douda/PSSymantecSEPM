$ErrorActionPreference = "Continue"
$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"

Write-Host "=== Smoke: Send-SEPMCommand (PS7) ==="

$results = @{}

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

# A1: ActiveScan with real computer
$results.A1 = TE -Id "A1" -Label "ActiveScan with real computer reaches API" `
    -Action { Send-SEPMCommand -Type ActiveScan -ComputerName 'WIN-P093KPK2K7Q' }

# A2: ActiveScan with non-existent computer (should still reach API)
$results.A2 = TE -Id "A2" -Label "ActiveScan with non-existent computer reaches API" `
    -Action { Send-SEPMCommand -Type ActiveScan -ComputerName 'NonExistentComputer12345' }

# A3: Pipeline input
$results.A3 = TE -Id "A3" -Label "ActiveScan via pipeline reaches API" `
    -Action { 'WIN-P093KPK2K7Q' | Send-SEPMCommand -Type ActiveScan }

# Final tally
$pass = ($results.Values | Where-Object { $_ -eq 'PASS' }).Count
$fail = ($results.Values | Where-Object { $_ -eq 'FAIL' }).Count
Write-Host "`n=== Results: $pass PASS, $fail FAIL ===" -ForegroundColor $(if ($fail -gt 0) { 'Red' } else { 'Green' })

if ($fail -gt 0) {
    Write-Error "Smoke tests failed: $fail failure(s)"
    exit 1
}
