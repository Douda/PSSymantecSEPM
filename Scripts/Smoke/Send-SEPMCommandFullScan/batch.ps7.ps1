$ErrorActionPreference = "Continue"
$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"

Write-Host "=== Smoke: Send-SEPMCommandFullScan (PS7) ==="

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

$results.B1 = TE -Id "B1" -Label "FullScan with non-existent computer reaches API" `
    -Action { Send-SEPMCommandFullScan -ComputerName 'NonExistentComputer12345' }

$results.B2 = TE -Id "B2" -Label "FullScan with non-existent group reaches API" `
    -Action { Send-SEPMCommandFullScan -GroupName 'NonExistent\Group\Path' }

$results.B3 = TE -Id "B3" -Label "FullScan via pipeline reaches API" `
    -Action { 'NonExistentComputer12345' | Send-SEPMCommandFullScan }

$pass = ($results.Values | Where-Object { $_ -eq 'PASS' }).Count
$fail = ($results.Values | Where-Object { $_ -eq 'FAIL' }).Count
Write-Host "`n=== Results: $pass PASS, $fail FAIL ===" -ForegroundColor $(if ($fail -gt 0) { 'Red' } else { 'Green' })

if ($fail -gt 0) {
    Write-Error "Smoke tests failed: $fail failure(s)"
    exit 1
}
