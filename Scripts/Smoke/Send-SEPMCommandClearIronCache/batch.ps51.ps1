# Smoke verification for Send-SEPMCommandClearIronCache (PS5.1)
$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"
. "$RepoRoot\Common-PS51.ps1"

Write-Host "=== Smoke: Send-SEPMCommandClearIronCache (PS5.1) ==="

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

$sha256Hash = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
$md5Hash = 'd41d8cd98f00b204e9800998ecf8427e'

$results.A1 = TE51 "A1" "ClearIronCache SHA256 to non-existent computer" `
    { Send-SEPMCommandClearIronCache -ComputerName 'NonExistentPC_SmokeTest' -SHA256 $sha256Hash }

$results.A2 = TE51 "A2" "ClearIronCache to non-existent group" `
    { Send-SEPMCommandClearIronCache -GroupName 'My Company\NonExistentSmokeGroup' }

$results.A3 = TE51 "A3" "ClearIronCache MD5 to non-existent computer" `
    { Send-SEPMCommandClearIronCache -ComputerName 'NonExistentPC_SmokeTest' -MD5 $md5Hash }

# Summary
$pass = ($results.Values | Where-Object { $_ -eq 'PASS' }).Count
$fail = ($results.Values | Where-Object { $_ -eq 'FAIL' }).Count
Write-Host "`n=== Results: $pass PASS, $fail FAIL ===" -ForegroundColor $(if ($fail -gt 0) { 'Red' } else { 'Green' })

if ($fail -gt 0) {
    Write-Error "Smoke tests failed: $fail failure(s)"
    exit 1
}
