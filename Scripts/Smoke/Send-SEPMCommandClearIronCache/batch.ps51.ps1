# Smoke verification for Send-SEPMCommandClearIronCache (PS5.1)
$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"
. "$RepoRoot\Common-PS51.ps1"

Write-Host "=== Smoke: Send-SEPMCommandClearIronCache (PS5.1) ==="

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

$sha256Hash = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
$md5Hash = 'd41d8cd98f00b204e9800998ecf8427e'

# A1: ClearIronCache dispatch to non-existent computer with SHA256
Assert-NotNull "A1" "ClearIronCache dispatch SHA256 to non-existent computer" {
    Send-SEPMCommandClearIronCache -ComputerName 'NonExistentPC_SmokeTest' -SHA256 $sha256Hash
}

# A2: ClearIronCache dispatch to non-existent group
Assert-NotNull "A2" "ClearIronCache dispatch to non-existent group" {
    Send-SEPMCommandClearIronCache -GroupName 'My Company\NonExistentSmokeGroup'
}

# A3: ClearIronCache with MD5 hash
Assert-NotNull "A3" "ClearIronCache dispatch MD5 to non-existent computer" {
    Send-SEPMCommandClearIronCache -ComputerName 'NonExistentPC_SmokeTest' -MD5 $md5Hash
}

# Summary
Write-Host "`n========== SUMMARY (PS5.1) =========="
Write-Host "TOTAL: $($pass+$fail) tests, $pass pass, $fail fail"
