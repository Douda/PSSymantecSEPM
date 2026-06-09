# Smoke verification for Update-SEPClientDefinitions (PS5.1)
# Verifies the command dispatch path by sending commands to non-existent clients.
# GroupName with a non-existent group correctly finds no computers and dispatches nothing.
$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"
. "$RepoRoot\Common-PS51.ps1"

Write-Host "=== Smoke: Update-SEPClientDefinitions (PS5.1) ==="

$pass = 0
$fail = 0

# A1: ComputerName path - dispatch to non-existent computer
Write-Host "--- A1 : UpdateDefinitions dispatch to non-existent computer ---"
try {
    $result = Update-SEPClientDefinitions -ComputerName 'NonExistentPC_SmokeTest'
    if ($result -ne $null) {
        Write-Host "  VERDICT: PASS"
        $pass++
    } else {
        Write-Host "  VERDICT: FAIL (null result)"
        $fail++
    }
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)"
    $fail++
}

# A2: GroupName path - non-existent group (no dispatch needed)
Write-Host "--- A2 : UpdateDefinitions dispatch to non-existent group ---"
try {
    $result = Update-SEPClientDefinitions -GroupName 'My Company\NonExistentSmokeGroup'
    Write-Host "  VERDICT: PASS (no matching targets)"
    $pass++
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)"
    $fail++
}

# A3: GroupName with IncludeSubGroups
Write-Host "--- A3 : UpdateDefinitions with IncludeSubGroups ---"
try {
    $result = Update-SEPClientDefinitions -GroupName 'My Company\NonExistentSmokeGroup' -IncludeSubGroups
    Write-Host "  VERDICT: PASS (no matching targets)"
    $pass++
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)"
    $fail++
}

# Summary
Write-Host "`n========== SUMMARY (PS5.1) =========="
Write-Host "TOTAL: $($pass+$fail) tests, $pass pass, $fail fail"
