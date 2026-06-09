# Smoke verification for Send-SEPMCommandClearIronCache (PS7)
# Verifies the command dispatch path by sending commands to non-existent clients.
# The API returns validation errors, which confirms the dispatch was attempted.
$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"

Write-Host "=== Smoke: Send-SEPMCommandClearIronCache (PS7) ==="

$sha256Hash = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
$md5Hash = 'd41d8cd98f00b204e9800998ecf8427e'

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

$results.A1 = TE -Id "A1" -Label "ClearIronCache SHA256 to non-existent computer" `
    -Action { Send-SEPMCommandClearIronCache -ComputerName 'NonExistentPC_SmokeTest' -SHA256 $sha256Hash }

$results.A2 = TE -Id "A2" -Label "ClearIronCache to non-existent group" `
    -Action { Send-SEPMCommandClearIronCache -GroupName 'My Company\NonExistentSmokeGroup' }

$results.A3 = TE -Id "A3" "ClearIronCache MD5 to non-existent computer" `
    -Action { Send-SEPMCommandClearIronCache -ComputerName 'NonExistentPC_SmokeTest' -MD5 $md5Hash }

# Summary
Write-Host "`n========== SUMMARY (PS7) ==========" -ForegroundColor Yellow
$pass = 0; $fail = 0
foreach ($k in $results.Keys | Sort-Object) {
    $v = $results[$k]
    if ($v -eq "PASS") { $pass++; Write-Host "  $k : PASS" -ForegroundColor Green }
    else { $fail++; Write-Host "  $k : FAIL" -ForegroundColor Red }
}
Write-Host "TOTAL: $($pass+$fail) tests, $pass pass, $fail fail" -ForegroundColor Yellow
