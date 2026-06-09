$ErrorActionPreference = "Continue"
$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"

Write-Host "=== Smoke: Send-SEPMCommandActiveScan (PS7) ==="

$results = @{}

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

# ── ComputerName (non-existent) ──
$results.A1 = TE -Id "A1" -Label "ActiveScan with non-existent computer reaches API" `
    -Action { Send-SEPMCommandActiveScan -ComputerName 'NonExistentComputer12345' }

# ── GroupName (non-existent) ──
$results.A2 = TE -Id "A2" -Label "ActiveScan with non-existent group reaches API" `
    -Action { Send-SEPMCommandActiveScan -GroupName 'NonExistent\Group\Path' }

# ── Pipeline input (non-existent) ──
$results.A3 = TE -Id "A3" -Label "ActiveScan via pipeline reaches API" `
    -Action { 'NonExistentComputer12345' | Send-SEPMCommandActiveScan }

# ── Final tally ──
$pass = ($results.Values | Where-Object { $_ -eq 'PASS' }).Count
$fail = ($results.Values | Where-Object { $_ -eq 'FAIL' }).Count
Write-Host "`n=== Results: $pass PASS, $fail FAIL ===" -ForegroundColor $(if ($fail -gt 0) { 'Red' } else { 'Green' })

if ($fail -gt 0) {
    Write-Error "Smoke tests failed: $fail failure(s)"
    exit 1
}
