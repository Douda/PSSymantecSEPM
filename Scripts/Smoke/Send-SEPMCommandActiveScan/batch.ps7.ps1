$ErrorActionPreference = "Continue"
$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"

Write-Host "=== Smoke: Send-SEPMCommandActiveScan (PS7) ==="

$fail = 0

# ── Helper: smoke test for mutation cmdlets where API errors are expected ──
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

# ── ComputerName (non-existent) ──
if ((TE -Id "A1" -Label "ActiveScan with non-existent computer reaches API" -Action { Send-SEPMCommandActiveScan -ComputerName 'NonExistentComputer12345' }) -eq "PASS") { $pass++ }

# ── GroupName (non-existent) ──
if ((TE -Id "A2" -Label "ActiveScan with non-existent group reaches API" -Action { Send-SEPMCommandActiveScan -GroupName 'NonExistent\Group\Path' }) -eq "PASS") { $pass++ }

# ── Pipeline input (non-existent) ──
if ((TE -Id "A3" -Label "ActiveScan via pipeline reaches API" -Action { 'NonExistentComputer12345' | Send-SEPMCommandActiveScan }) -eq "PASS") { $pass++ }

# ── Final tally ──
Write-Host "`n=== Results: $pass PASS, $fail FAIL ===" -ForegroundColor $(if ($fail -gt 0) { 'Red' } else { 'Green' })

if ($fail -gt 0) {
    Write-Error "Smoke tests failed: $fail failure(s)"
    exit 1
}
