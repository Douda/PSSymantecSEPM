$ErrorActionPreference = "Continue"
$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"

Write-Host "=== Smoke: Send-SEPMCommandFullScan (PS7) ==="

$fail = 0

function TE {
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

$pass = 0

if ((TE -Id "B1" -Label "FullScan with non-existent computer reaches API" -Action { Send-SEPMCommandFullScan -ComputerName 'NonExistentComputer12345' }) -eq "PASS") { $pass++ }
if ((TE -Id "B2" -Label "FullScan with non-existent group reaches API" -Action { Send-SEPMCommandFullScan -GroupName 'NonExistent\Group\Path' }) -eq "PASS") { $pass++ }
if ((TE -Id "B3" -Label "FullScan via pipeline reaches API" -Action { 'NonExistentComputer12345' | Send-SEPMCommandFullScan }) -eq "PASS") { $pass++ }

Write-Host "`n=== Results: $pass PASS, $fail FAIL ===" -ForegroundColor $(if ($fail -gt 0) { 'Red' } else { 'Green' })

if ($fail -gt 0) {
    Write-Error "Smoke tests failed: $fail failure(s)"
    exit 1
}
