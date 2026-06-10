$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"
. "$RepoRoot\Common-PS51.ps1"

Write-Host "=== Smoke: Send-SEPMCommand (PS5.1) ==="

$results = @{}

function TE51 {
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

$results.A1 = TE51 "A1" "ActiveScan with real computer reaches API" `
    { Send-SEPMCommand -Type ActiveScan -ComputerName 'WIN-P093KPK2K7Q' }

$results.A2 = TE51 "A2" "ActiveScan with non-existent computer reaches API" `
    { Send-SEPMCommand -Type ActiveScan -ComputerName 'NonExistentComputer12345' }

$results.A3 = TE51 "A3" "ActiveScan via pipeline reaches API" `
    { 'WIN-P093KPK2K7Q' | Send-SEPMCommand -Type ActiveScan }

$pass = ($results.Values | Where-Object { $_ -eq 'PASS' }).Count
$fail = ($results.Values | Where-Object { $_ -eq 'FAIL' }).Count
Write-Host "`n=== Results: $pass PASS, $fail FAIL ===" -ForegroundColor $(if ($fail -gt 0) { 'Red' } else { 'Green' })

if ($fail -gt 0) {
    Write-Error "Smoke tests failed: $fail failure(s)"
    exit 1
}
