<#
.SYNOPSIS
    Unified shared infrastructure for all PSSymantecSEPM smoke scripts.

.DESCRIPTION
    Shared test helpers for all PSSymantecSEPM smoke scripts.

    Dot-source this from any smoke suite entry point after calling
    Initialize-SmokeBootstrap (which handles module import, config, and
    authentication). This file is callable from both PS 5.1 and PS 7+ —
    it contains no platform branching, no config file paths, and no
    module import.

    Provides:
      - T helper: standardized test execution with PASS/FAIL/SKIP verdicts
      - Skip helper: explicit test skip with reason
      - Write-Summary: parseable TOTAL line + exit code 1 on failure

    Example:

        . "$RepoRoot/Scripts/Smoke/Bootstrap.ps1"
        Initialize-SmokeBootstrap -RepoRoot $RepoRoot
        . "$RepoRoot/Scripts/Smoke/Common.ps1"

.NOTES
    PS 5.1 compatible — no ternary, no null-coalescing, no -SkipCertificateCheck.
    Authentication was moved to Bootstrap.ps1 / Initialize-SmokeBootstrap.
#>

$ErrorActionPreference = "Continue"

# ── Shared helper: T (test runner) ──
function T {
    <#
    .SYNOPSIS
        Standard smoke test runner for all cmdlet types.
    .PARAMETER Id
        Test ID (e.g., "A1", "B3").
    .PARAMETER Label
        Human-readable test description.
    .PARAMETER Action
        ScriptBlock that performs the mutation / API call.
    .PARAMETER Assert
        ScriptBlock that receives the Action output and returns $true (pass) or $false (fail).
    .PARAMETER ExpectedError
        Optional substring. If the Action throws or returns an API error containing this
        text, the test is classified as PASS (expected error scenario).
    .PARAMETER SleepMs
        Milliseconds to sleep after running Action (default 0). Use for mutation
        cmdlets that need SEPM to settle before asserting.
    .PARAMETER AssertTarget
        Optional ScriptBlock that produces the assertion subject. When provided,
        AssertTarget runs after Action (and after SleepMs) and its output is passed
        to Assert instead of Action's return value. Use for mutation cmdlets that
        need ground-truth verification against API state.
    .OUTPUTS
        String: "PASS", "FAIL", or "SKIP".
    #>
    param(
        $Id,
        $Label,
        [ScriptBlock]$Action,
        [ScriptBlock]$Assert,
        [string]$ExpectedError,
        [int]$SleepMs = 0,
        [ScriptBlock]$AssertTarget
    )
    Write-Host "--- $Id : $Label ---" -ForegroundColor Cyan
    try {
        $result = & $Action

        if ($result -is [string] -and $result -like "Error:*") {
            if ($ExpectedError -and $result -like "*$ExpectedError*") {
                Write-Host "  VERDICT: PASS (expected error: $ExpectedError)" -ForegroundColor Green
                return "PASS"
            }
            Write-Host "  VERDICT: FAIL (API error: $result)" -ForegroundColor Red
            return "FAIL"
        }

        if ($SleepMs -gt 0) { Start-Sleep -Milliseconds $SleepMs }
        if ($AssertTarget) {
            $assertInput = & $AssertTarget
        } else {
            $assertInput = $result
        }
        $ok = & $Assert $assertInput
        if ($ok) { Write-Host "  VERDICT: PASS" -ForegroundColor Green; return "PASS" }
        else     { Write-Host "  VERDICT: FAIL" -ForegroundColor Red;   return "FAIL" }
    } catch {
        if ($ExpectedError -and $_.Exception.Message -like "*$ExpectedError*") {
            Write-Host "  VERDICT: PASS (expected error: $ExpectedError)" -ForegroundColor Green
            return "PASS"
        }
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        return "FAIL"
    }
}

# ── Shared helper: Skip (explicit skip) ──
function Skip {
    <#
    .SYNOPSIS
        Emit an explicit SKIP verdict with a reason.
    .PARAMETER Id
        Test ID.
    .PARAMETER Label
        Human-readable test description.
    .PARAMETER Reason
        Why the test was skipped.
    .OUTPUTS
        String: "SKIP".
    #>
    param($Id, $Label, $Reason)
    Write-Host "--- $Id : $Label ---" -ForegroundColor Cyan
    Write-Host "  SKIP: $Reason" -ForegroundColor Yellow
    return "SKIP"
}

# ── Shared helper: Write-Summary ──
function Write-Summary {
    <#
    .SYNOPSIS
        Emit a parseable test summary and exit with code 1 on failure.
    .DESCRIPTION
        Takes a hashtable of { testId: "PASS"|"FAIL"|"SKIP" }, sorts keys,
        emits per-test one-liners, then a parseable TOTAL line:
          TOTAL: N tests, N pass, N fail, N skip
        By default exits with code 1 if any failures. Pass -OnFailure { }
        to suppress the exit (useful in tests).
    .PARAMETER Results
        Hashtable mapping test IDs to verdict strings.
    .PARAMETER Label
        Optional label for the summary header (default: "Smoke Tests").
    .PARAMETER OnFailure
        Optional ScriptBlock invoked when failures are present. Defaults to
        { exit 1 }. Pass { } to suppress exit during unit testing.
    #>
    param(
        [hashtable]$Results,
        [string]$Label = "Smoke Tests",
        [ScriptBlock]$OnFailure = { exit 1 }
    )
    $pass = 0; $fail = 0; $skip = 0
    Write-Host "`n========== $Label ==========" -ForegroundColor Yellow
    foreach ($k in $Results.Keys | Sort-Object) {
        $v = $Results[$k]
        if ($v -eq "PASS") { $pass++; Write-Host "  $k : PASS" -ForegroundColor Green }
        elseif ($v -eq "SKIP") { $skip++; Write-Host "  $k : SKIP" -ForegroundColor Yellow }
        else { $fail++; Write-Host "  $k : FAIL" -ForegroundColor Red }
    }
    $total = $pass + $fail + $skip
    Write-Host "TOTAL: $total tests, $pass pass, $fail fail, $skip skip" -ForegroundColor Yellow
    if ($fail -gt 0) {
        & $OnFailure
    }
}
