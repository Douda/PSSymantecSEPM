[CmdletBinding()]
param()

Describe 'Write-CategoryVerboseOutput' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'OK line format' {
        It 'outputs an OK verbose line with metric and step count' {
            InModuleScope PSSymantecSEPM {
                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                Start-Sleep -Milliseconds 5
                $sw.Stop()

                $originalPref = $VerbosePreference
                $VerbosePreference = 'Continue'
                try {
                    $result = Write-CategoryVerboseOutput -Category 'Domains' -Data @('d1', 'd2', 'd3') -Stopwatch $sw -StepNumber 1 -TotalSteps 25 -Failed $false 4>&1
                } finally {
                    $VerbosePreference = $originalPref
                }

                $result | Should -Not -BeNullOrEmpty
                $result | Should -Match 'OK'
                $result | Should -Match '3 domains'
                $result | Should -Match '01/25'
                $result | Should -Match '\('  # has duration
            }
        }

        It 'includes category name in the line' {
            InModuleScope PSSymantecSEPM {
                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                $sw.Stop()

                $originalPref = $VerbosePreference
                $VerbosePreference = 'Continue'
                try {
                    $result = Write-CategoryVerboseOutput -Category 'FirewallPolicies' -Data @('p1') -Stopwatch $sw -StepNumber 2 -TotalSteps 25 -Failed $false 4>&1
                } finally {
                    $VerbosePreference = $originalPref
                }

                $result | Should -Match 'FirewallPolicies'
            }
        }
    }

    Context 'FAILED line format' {
        It 'outputs FAILED status and error metric when Failed is true' {
            InModuleScope PSSymantecSEPM {
                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                $sw.Stop()

                $originalPref = $VerbosePreference
                $VerbosePreference = 'Continue'
                try {
                    $result = Write-CategoryVerboseOutput -Category 'Domains' -Data $null -Stopwatch $sw -StepNumber 3 -TotalSteps 25 -Failed $true 4>&1
                } finally {
                    $VerbosePreference = $originalPref
                }

                $result | Should -Not -BeNullOrEmpty
                $result | Should -Match 'FAILED'
                $result | Should -Match 'error'
            }
        }
    }

    Context 'Null and empty data' {
        It 'displays OK (empty) for null data' {
            InModuleScope PSSymantecSEPM {
                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                $sw.Stop()

                $originalPref = $VerbosePreference
                $VerbosePreference = 'Continue'
                try {
                    $result = Write-CategoryVerboseOutput -Category 'Computers' -Data $null -Stopwatch $sw -StepNumber 4 -TotalSteps 25 -Failed $false 4>&1
                } finally {
                    $VerbosePreference = $originalPref
                }

                $result | Should -Match 'OK \(empty\)'
            }
        }

        It 'displays OK (empty) for empty array data' {
            InModuleScope PSSymantecSEPM {
                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                $sw.Stop()

                $originalPref = $VerbosePreference
                $VerbosePreference = 'Continue'
                try {
                    $result = Write-CategoryVerboseOutput -Category 'Groups' -Data @() -Stopwatch $sw -StepNumber 5 -TotalSteps 25 -Failed $false 4>&1
                } finally {
                    $VerbosePreference = $originalPref
                }

                $result | Should -Match 'OK \(empty\)'
            }
        }
    }

    Context 'Duration formatting' {
        It 'shows sub-second duration in ms' {
            InModuleScope PSSymantecSEPM {
                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                Start-Sleep -Milliseconds 5
                $sw.Stop()

                $originalPref = $VerbosePreference
                $VerbosePreference = 'Continue'
                try {
                    $result = Write-CategoryVerboseOutput -Category 'Domains' -Data @('d1') -Stopwatch $sw -StepNumber 6 -TotalSteps 25 -Failed $false 4>&1
                } finally {
                    $VerbosePreference = $originalPref
                }

                $result | Should -Match '\(\d+ms\)'
            }
        }

        It 'shows 0ms for instant stopwatch' {
            InModuleScope PSSymantecSEPM {
                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                $sw.Stop()

                $originalPref = $VerbosePreference
                $VerbosePreference = 'Continue'
                try {
                    $result = Write-CategoryVerboseOutput -Category 'Domains' -Data @('d1') -Stopwatch $sw -StepNumber 7 -TotalSteps 25 -Failed $false 4>&1
                } finally {
                    $VerbosePreference = $originalPref
                }

                $result | Should -Match '\(0ms\)'
            }
        }
    }

    Context 'Step numbering' {
        It 'zero-pads step numbers to 2 digits' {
            InModuleScope PSSymantecSEPM {
                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                $sw.Stop()

                $originalPref = $VerbosePreference
                $VerbosePreference = 'Continue'
                try {
                    $result = Write-CategoryVerboseOutput -Category 'Domains' -Data @('d1') -Stopwatch $sw -StepNumber 3 -TotalSteps 25 -Failed $false 4>&1
                } finally {
                    $VerbosePreference = $originalPref
                }

                $result | Should -Match '\[03/25\]'
            }
        }

        It 'handles double-digit step numbers' {
            InModuleScope PSSymantecSEPM {
                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                $sw.Stop()

                $originalPref = $VerbosePreference
                $VerbosePreference = 'Continue'
                try {
                    $result = Write-CategoryVerboseOutput -Category 'Computers' -Data @('c1') -Stopwatch $sw -StepNumber 13 -TotalSteps 25 -Failed $false 4>&1
                } finally {
                    $VerbosePreference = $originalPref
                }

                $result | Should -Match '\[13/25\]'
            }
        }
    }

    Context 'Timestamp format' {
        It 'starts with HH:mm:ss timestamp' {
            InModuleScope PSSymantecSEPM {
                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                $sw.Stop()

                $originalPref = $VerbosePreference
                $VerbosePreference = 'Continue'
                try {
                    $result = Write-CategoryVerboseOutput -Category 'Domains' -Data @('d1') -Stopwatch $sw -StepNumber 1 -TotalSteps 25 -Failed $false 4>&1
                } finally {
                    $VerbosePreference = $originalPref
                }

                $result | Should -Match '^\[\d{2}:\d{2}:\d{2}\]'
            }
        }
    }
}
