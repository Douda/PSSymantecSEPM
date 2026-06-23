# Unit tests for Common.ps1 helper functions
# These test T, Skip, and Write-Summary output formatting in isolation.
# Exit-code behavior is verified during live smoke tests.

Describe 'Common.ps1' {

    # Functions are dot-sourced from the real Common.ps1 file.
    # Auth is no longer in Common.ps1 — it was moved to Bootstrap.ps1.

    BeforeAll {
        $script:CommonRepoRoot = (Resolve-Path "$PSScriptRoot/..").Path
        . "$script:CommonRepoRoot/Scripts/Smoke/Common.ps1"
    }

    Context 'T helper' {
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

        It 'uses AssertTarget output instead of Action output for assertion' {
            $result = T "X9" "assert target test" `
                { return "ignored" } `
                { param($r) $r -eq 99 } `
                -AssertTarget { return 99 }
            $result | Should -Be "PASS"
        }

        It 'sleeps before asserting when SleepMs is set' {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $result = T "X10" "sleep test" `
                { return 42 } `
                { param($r) $r -eq 42 } `
                -SleepMs 200
            $sw.Stop()
            $result | Should -Be "PASS"
            $sw.ElapsedMilliseconds | Should -BeGreaterOrEqual 150
        }

        It 'existing tests work without AssertTarget (backward compat)' {
            $result = T "X11" "no assert target" { return "hello" } { param($r) $r -eq "hello" }
            $result | Should -Be "PASS"
        }
    }

    Context 'Skip helper' {
        It 'returns SKIP' {
            $result = Skip "S1" "skipped test" "no data available"
            $result | Should -Be "SKIP"
        }
    }

    Context 'Write-Summary' {
        It 'emits parseable TOTAL line' {
            $results = @{ A1 = "PASS"; A2 = "FAIL"; A3 = "SKIP" }
            $output = & { Write-Summary -Results $results -Label "Unit Test" -OnFailure { } *>&1 } | Out-String
            $output | Should -Match 'TOTAL: 3 tests, 1 pass, 1 fail, 1 skip'
        }

        It 'emits per-test one-liners sorted by key' {
            $results = @{ C = "PASS"; A = "PASS"; B = "FAIL" }
            $output = & { Write-Summary -Results $results -Label "Unit Test" -OnFailure { } *>&1 } | Out-String
            $output | Should -Match 'A : PASS'
            $output | Should -Match 'B : FAIL'
            $output | Should -Match 'C : PASS'
        }

        It 'all-pass result has zero fail count' {
            $results = @{ A1 = "PASS"; A2 = "PASS" }
            $output = & { Write-Summary -Results $results -Label "All Pass" -OnFailure { } *>&1 } | Out-String
            $output | Should -Match 'TOTAL: 2 tests, 2 pass, 0 fail, 0 skip'
        }

        It 'fail count matches number of FAIL verdicts' {
            $results = @{ A1 = "PASS"; A2 = "FAIL"; A3 = "FAIL" }
            $output = & { Write-Summary -Results $results -Label "Two Fail" -OnFailure { } *>&1 } | Out-String
            $output | Should -Match 'TOTAL: 3 tests, 1 pass, 2 fail, 0 skip'
        }
    }
}
