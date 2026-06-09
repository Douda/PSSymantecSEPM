$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"
. "$RepoRoot\Common-PS51.ps1"

Write-Host "=== Smoke: Send-SEPMCommandActiveScan (PS5.1) ==="

$results = @{}
$fail = 0

# ── Helper ──
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

$results.A1 = TE51 "A1" "ActiveScan with non-existent computer reaches API" `
    { Send-SEPMCommandActiveScan -ComputerName 'NonExistentComputer12345' }

$results.A2 = TE51 "A2" "ActiveScan with non-existent group reaches API" `
    { Send-SEPMCommandActiveScan -GroupName 'NonExistent\Group\Path' }

$results.A3 = TE51 "A3" "ActiveScan via pipeline reaches API" `
    { 'NonExistentComputer12345' | Send-SEPMCommandActiveScan }

$pass = ($results.Values | Where-Object { $_ -eq 'PASS' }).Count
Write-Host "`n=== Results: $pass PASS, $fail FAIL ===" -ForegroundColor $(if ($fail -gt 0) { 'Red' } else { 'Green' })

if ($fail -gt 0) {
    throw "Smoke tests failed: $fail failure(s)"
}
