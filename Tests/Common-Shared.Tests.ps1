# Unit tests for Common-Shared.ps1 helper functions
# These test T, Skip, and Write-Summary output formatting in isolation.
# Exit-code behavior is verified during live smoke tests.

Describe 'Common-Shared.ps1' {

    # Functions are tested inline with identical source code to Common-Shared.ps1.
    # Auth (Set-SEPMAuthentication/Get-SEPMAccessToken) is not exercised here —
    # those require the module and are verified during smoke tests.

    Context 'T helper' {
        BeforeAll {
            function T {
                param(
                    $Id,
                    $Label,
                    [ScriptBlock]$Action,
                    [ScriptBlock]$Assert,
                    [string]$ExpectedError
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

                    $ok = & $Assert $result
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
        }

        It 'returns PASS for passing assertion' {
            $result = T "X1" "passing test" { return 42 } { param($r) $r -eq 42 }
            $result | Should -Be "PASS"
        }

        It 'returns FAIL for failing assertion' {
            $result = T "X2" "failing test" { return 42 } { param($r) $r -eq 99 }
            $result | Should -Be "FAIL"
        }

        It 'returns FAIL when Action throws' {
            $result = T "X3" "throwing test" { throw "boom" } { param($r) $true }
            $result | Should -Be "FAIL"
        }

        It 'returns FAIL for API error string' {
            $result = T "X4" "api error" { return "Error: something bad" } { param($r) $true }
            $result | Should -Be "FAIL"
        }

        It 'returns PASS when API error matches ExpectedError' {
            $result = T "X5" "expected api error" `
                { return "Error: no data found" } `
                { param($r) $true } `
                -ExpectedError "no data found"
            $result | Should -Be "PASS"
        }

        It 'returns PASS when exception matches ExpectedError' {
            $result = T "X6" "expected exception" `
                { throw "record not found in database" } `
                { param($r) $true } `
                -ExpectedError "not found"
            $result | Should -Be "PASS"
        }

        It 'returns FAIL when exception does not match ExpectedError' {
            $result = T "X7" "unexpected exception" `
                { throw "permission denied" } `
                { param($r) $true } `
                -ExpectedError "not found"
            $result | Should -Be "FAIL"
        }

        It 'returns FAIL when API error does not match ExpectedError' {
            $result = T "X8" "unexpected api error" `
                { return "Error: timeout" } `
                { param($r) $true } `
                -ExpectedError "not found"
            $result | Should -Be "FAIL"
        }
    }

    Context 'Skip helper' {
        BeforeAll {
            function Skip {
                param($Id, $Label, $Reason)
                Write-Host "--- $Id : $Label ---" -ForegroundColor Cyan
                Write-Host "  SKIP: $Reason" -ForegroundColor Yellow
                return "SKIP"
            }
        }

        It 'returns SKIP' {
            $result = Skip "S1" "skipped test" "no data available"
            $result | Should -Be "SKIP"
        }
    }

    Context 'Write-Summary' {
        BeforeAll {
            # Test variant of Write-Summary that does NOT call exit.
            # Exit-code behavior is verified during smoke tests.
            function Write-Summary-Test {
                param(
                    [hashtable]$Results,
                    [string]$Label = "Smoke Tests"
                )
                $pass = 0; $fail = 0; $skip = 0
                $lines = @()
                $lines += "`n========== $Label =========="
                foreach ($k in $Results.Keys | Sort-Object) {
                    $v = $Results[$k]
                    if ($v -eq "PASS") { $pass++; $lines += "  $k : PASS" }
                    elseif ($v -eq "SKIP") { $skip++; $lines += "  $k : SKIP" }
                    else { $fail++; $lines += "  $k : FAIL" }
                }
                $total = $pass + $fail + $skip
                $lines += "TOTAL: $total tests, $pass pass, $fail fail, $skip skip"
                Write-Host ($lines -join "`n") -ForegroundColor Yellow
            }
        }

        It 'emits parseable TOTAL line' {
            $results = @{ A1 = "PASS"; A2 = "FAIL"; A3 = "SKIP" }
            $output = & { Write-Summary-Test -Results $results -Label "Unit Test" *>&1 } | Out-String
            $output | Should -Match 'TOTAL: 3 tests, 1 pass, 1 fail, 1 skip'
        }

        It 'emits per-test one-liners sorted by key' {
            $results = @{ C = "PASS"; A = "PASS"; B = "FAIL" }
            $output = & { Write-Summary-Test -Results $results -Label "Unit Test" *>&1 } | Out-String
            $output | Should -Match 'A : PASS'
            $output | Should -Match 'B : FAIL'
            $output | Should -Match 'C : PASS'
        }

        It 'all-pass result has zero fail count' {
            $results = @{ A1 = "PASS"; A2 = "PASS" }
            $output = & { Write-Summary-Test -Results $results -Label "All Pass" *>&1 } | Out-String
            $output | Should -Match 'TOTAL: 2 tests, 2 pass, 0 fail, 0 skip'
        }

        It 'fail count matches number of FAIL verdicts' {
            $results = @{ A1 = "PASS"; A2 = "FAIL"; A3 = "FAIL" }
            $output = & { Write-Summary-Test -Results $results -Label "Two Fail" *>&1 } | Out-String
            $output | Should -Match 'TOTAL: 3 tests, 1 pass, 2 fail, 0 skip'
        }
    }
}
