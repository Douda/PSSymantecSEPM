$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"
. "$RepoRoot\Common-PS51.ps1"

Write-Host "=== Smoke: Send-SEPMCommandFullScan (PS5.1) ==="

$results = @{}
$fail = 0

function TE51 {
    param($Id, $Label, [ScriptBlock]$Action)
    Write-Host "--- $Id : $Label ---" -ForegroundColor Cyan
    try {
        $result = & $Action
        if ($null -eq $result) {
            Write-Host "  VERDICT: FAIL (null response)" -ForegroundColor Red
            $script:fail++
            return "FAIL"
        }
        Write-Host "  VERDICT: PASS (API reached)" -ForegroundColor Green
        return "PASS"
    } catch {
        Write-Host "  VERDICT: FAIL (exception: $($_.Exception.Message))" -ForegroundColor Red
        $script:fail++
        return "FAIL"
    }
}

$results.B1 = TE51 "B1" "FullScan with non-existent computer reaches API" `
    { Send-SEPMCommandFullScan -ComputerName 'NonExistentComputer12345' }

$results.B2 = TE51 "B2" "FullScan with non-existent group reaches API" `
    { Send-SEPMCommandFullScan -GroupName 'NonExistent\Group\Path' }

$results.B3 = TE51 "B3" "FullScan via pipeline reaches API" `
    { 'NonExistentComputer12345' | Send-SEPMCommandFullScan }

$pass = ($results.Values | Where-Object { $_ -eq 'PASS' }).Count
Write-Host "`n=== Results: $pass PASS, $fail FAIL ===" -ForegroundColor $(if ($fail -gt 0) { 'Red' } else { 'Green' })

if ($fail -gt 0) {
    throw "Smoke tests failed: $fail failure(s)"
}
