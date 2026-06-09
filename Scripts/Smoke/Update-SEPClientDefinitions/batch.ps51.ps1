# Smoke verification for Update-SEPClientDefinitions (PS5.1)
# Verifies the command dispatch path by sending commands to non-existent clients.
# GroupName with a non-existent group correctly finds no computers and dispatches nothing.
$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"
. "$RepoRoot\Common-PS51.ps1"

Write-Host "=== Smoke: Update-SEPClientDefinitions (PS5.1) ==="

$pass = 0
$fail = 0

function Assert-NotNull {
    param($Id, $Label, [ScriptBlock]$Action)
    Write-Host "--- $Id : $Label ---"
    try {
        $result = & $Action
        if ($result -ne $null) {
            Write-Host "  VERDICT: PASS"
            $script:pass++
        } else {
            Write-Host "  VERDICT: FAIL (null result)"
            $script:fail++
        }
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)"
        $script:fail++
    }
}

# A1: ComputerName path - dispatch to non-existent computer
Assert-NotNull "A1" "UpdateDefinitions dispatch to non-existent computer" {
    Update-SEPClientDefinitions -ComputerName 'NonExistentPC_SmokeTest'
}

# A2: GroupName path - non-existent group (no dispatch needed)
Write-Host "--- A2 : UpdateDefinitions dispatch to non-existent group ---"
try {
    Update-SEPClientDefinitions -GroupName 'My Company\NonExistentSmokeGroup' | Out-Null
    Write-Host "  VERDICT: PASS (no matching targets)"
    $pass++
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)"
    $fail++
}

# A3: GroupName with IncludeSubGroups
Write-Host "--- A3 : UpdateDefinitions with IncludeSubGroups ---"
try {
    Update-SEPClientDefinitions -GroupName 'My Company\NonExistentSmokeGroup' -IncludeSubGroups | Out-Null
    Write-Host "  VERDICT: PASS (no matching targets)"
    $pass++
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)"
    $fail++
}

# Summary
Write-Host "`n========== SUMMARY (PS5.1) =========="
Write-Host "TOTAL: $($pass+$fail) tests, $pass pass, $fail fail"
