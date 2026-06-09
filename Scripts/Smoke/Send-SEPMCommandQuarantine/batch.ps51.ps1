# Smoke verification for Send-SEPMCommandQuarantine (PS5.1)
$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"
. "$RepoRoot\Common-PS51.ps1"

Write-Host "=== Smoke: Send-SEPMCommandQuarantine (PS5.1) ==="

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

# A1: Command dispatch to non-existent computer
Assert-NotNull "A1" "Quarantine dispatch to non-existent computer" {
    Send-SEPMCommandQuarantine -ComputerName 'NonExistentPC_SmokeTest'
}

# A2: Command dispatch with GroupName
Assert-NotNull "A2" "Quarantine dispatch to non-existent group" {
    Send-SEPMCommandQuarantine -GroupName 'My Company\NonExistentSmokeGroup'
}

# A3: Unquarantine with non-existent computer
Assert-NotNull "A3" "Unquarantine dispatch with undo=true" {
    Send-SEPMCommandQuarantine -ComputerName 'NonExistentPC_SmokeTest' -Unquarantine
}

# Summary
Write-Host "`n========== SUMMARY (PS5.1) =========="
Write-Host "TOTAL: $($pass+$fail) tests, $pass pass, $fail fail"
