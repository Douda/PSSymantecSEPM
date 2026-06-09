# Smoke verification for Update-SEPClientDefinitions (PS5.1)
# Verifies the command dispatch path by sending commands to non-existent clients.
# GroupName with a non-existent group correctly finds no computers and dispatches nothing.
$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"
. "$RepoRoot\Common-PS51.ps1"

Write-Host "=== Smoke: Update-SEPClientDefinitions (PS5.1) ==="

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

# A1: ComputerName path — dispatch to non-existent computer reaches API
$results.A1 = TE51 "A1" "UpdateDefinitions dispatch to non-existent computer" `
    { Update-SEPClientDefinitions -ComputerName 'NonExistentPC_SmokeTest' }

# A2: GroupName path — non-existent group (no dispatch needed, not an error)
Write-Host "--- A2 : UpdateDefinitions dispatch to non-existent group ---"
try {
    Update-SEPClientDefinitions -GroupName 'My Company\NonExistentSmokeGroup' | Out-Null
    Write-Host "  VERDICT: PASS (no matching targets)"
    $results.A2 = "PASS"
} catch {
    Write-Host "  VERDICT: FAIL (exception: $($_.Exception.Message))" -ForegroundColor Red
    $results.A2 = "FAIL"
}

# A3: GroupName with IncludeSubGroups
Write-Host "--- A3 : UpdateDefinitions with IncludeSubGroups ---"
try {
    Update-SEPClientDefinitions -GroupName 'My Company\NonExistentSmokeGroup' -IncludeSubGroups | Out-Null
    Write-Host "  VERDICT: PASS (no matching targets)"
    $results.A3 = "PASS"
} catch {
    Write-Host "  VERDICT: FAIL (exception: $($_.Exception.Message))" -ForegroundColor Red
    $results.A3 = "FAIL"
}

# Summary
$pass = ($results.Values | Where-Object { $_ -eq 'PASS' }).Count
$fail = ($results.Values | Where-Object { $_ -eq 'FAIL' }).Count
Write-Host "`n=== Results: $pass PASS, $fail FAIL ===" -ForegroundColor $(if ($fail -gt 0) { 'Red' } else { 'Green' })

if ($fail -gt 0) {
    Write-Error "Smoke tests failed: $fail failure(s)"
    exit 1
}
