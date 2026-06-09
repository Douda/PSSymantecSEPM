# Smoke batch: Get-SEPMVersion (PS 5.1)
# Deploy: cp -r ./Output/PSSymantecSEPM /home/douda/Windows/PSSymantecSEPM
# Run via WinRM: python3 Scripts/invoke-winrm.py 'C:\Users\smokeuser\Desktop\Shared\Get-SEPMVersion\batch.ps51.ps1'

$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"
. "$RepoRoot\Common-PS51.ps1"

function T {
    param($Id, $Label, [ScriptBlock]$Action, [ScriptBlock]$Assert)
    Write-Host "--- $Id : $Label ---" -ForegroundColor Cyan
    try {
        $result = & $Action

        if ($result -is [string] -and $result -like "Error:*") {
            Write-Host "  VERDICT: FAIL (API error: $result)" -ForegroundColor Red
            return "FAIL"
        }

        $ok = & $Assert $result
        if ($ok) { Write-Host "  VERDICT: PASS" -ForegroundColor Green; return "PASS" }
        else     { Write-Host "  VERDICT: FAIL" -ForegroundColor Red;   return "FAIL" }
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        return "FAIL"
    }
}

$results = @{}

$results.A1 = T "A1" "Get-SEPMVersion" `
    { Get-SEPMVersion } `
    { param($r) $r -ne $null -and $r.API_SEQUENCE -ne $null -and $r.API_VERSION -ne $null -and $r.version -ne $null }

# === Summary ===
Write-Host "`n========== SUMMARY (PS5.1 Get-SEPMVersion) ==========" -ForegroundColor Yellow
$pass = 0; $fail = 0
foreach ($k in $results.Keys | Sort-Object) {
    $v = $results[$k]
    if ($v -eq "PASS") { $pass++; Write-Host "  $k : PASS" -ForegroundColor Green }
    else { $fail++; Write-Host "  $k : FAIL" -ForegroundColor Red }
}
Write-Host "TOTAL: $($pass+$fail) tests, $pass pass, $fail fail" -ForegroundColor Yellow
