<#
.SYNOPSIS
    PS5.1 shared infrastructure for all PSSymantecSEPM smoke scripts.

.DESCRIPTION
    Dot-source this from any PS5.1 smoke suite entry point.

    Provides:
      - Authentication (credential -> token)
      - T helper: standardized test execution with PASS/FAIL/SKIP verdicts
      - Skip helper: explicit test skip with reason
      - Write-Summary: parseable TOTAL line + exit code 1 on failure

    The caller must:
      1. Import the PSSymantecSEPM module
      2. Configure cert bypass
      3. Set $RepoRoot before dot-sourcing this file.

.NOTES
    PS 5.1 compatible -- no ternary, no null-coalescing, no -SkipCertificateCheck.
#>

$ErrorActionPreference = "Continue"

# -- Authentication --
$SmokeCredPassword = ConvertTo-SecureString -String 'MyComplexPassword1!' -AsPlainText -Force
$SmokeCredential   = New-Object System.Management.Automation.PSCredential -ArgumentList 'admin', $SmokeCredPassword
Set-SEPMAuthentication -Credential $SmokeCredential -ErrorAction SilentlyContinue

Get-SEPMAccessToken | Out-Null

# -- Shared helper: T (test runner) --
function T {
    param(
        $Id,
        $Label,
        [ScriptBlock]$Action,
        [ScriptBlock]$Assert,
        [string]$ExpectedError,
        [int]$SleepMs = 0,
        [ScriptBlock]$AssertTarget
    )
    Write-Host "--- $Id : $Label ---"
    try {
        $result = & $Action

        if ($result -is [string] -and $result -like "Error:*") {
            if ($ExpectedError -and $result -like "*$ExpectedError*") {
                Write-Host "  VERDICT: PASS (expected error: $ExpectedError)"
                return "PASS"
            }
            Write-Host "  VERDICT: FAIL (API error: $result)"
            return "FAIL"
        }

        if ($SleepMs -gt 0) { Start-Sleep -Milliseconds $SleepMs }
        if ($AssertTarget) {
            $assertInput = & $AssertTarget
        } else {
            $assertInput = $result
        }
        $ok = & $Assert $assertInput
        if ($ok) { Write-Host "  VERDICT: PASS"; return "PASS" }
        else     { Write-Host "  VERDICT: FAIL"; return "FAIL" }
    } catch {
        if ($ExpectedError -and $_.Exception.Message -like "*$ExpectedError*") {
            Write-Host "  VERDICT: PASS (expected error: $ExpectedError)"
            return "PASS"
        }
        Write-Host "  ERROR: $($_.Exception.Message)"
        return "FAIL"
    }
}

# -- Shared helper: Skip (explicit skip) --
function Skip {
    param($Id, $Label, $Reason)
    Write-Host "--- $Id : $Label ---"
    Write-Host "  SKIP: $Reason"
    return "SKIP"
}

# -- Shared helper: Write-Summary --
function Write-Summary {
    param(
        [hashtable]$Results,
        [string]$Label = "Smoke Tests"
    )
    $pass = 0; $fail = 0; $skip = 0
    Write-Host "`n========== $Label =========="
    foreach ($k in $Results.Keys | Sort-Object) {
        $v = $Results[$k]
        if ($v -eq "PASS") { $pass++; Write-Host "  $k : PASS" }
        elseif ($v -eq "SKIP") { $skip++; Write-Host "  $k : SKIP" }
        else { $fail++; Write-Host "  $k : FAIL" }
    }
    $total = $pass + $fail + $skip
    Write-Host "TOTAL: $total tests, $pass pass, $fail fail, $skip skip"
    if ($fail -gt 0) {
        exit 1
    }
}
