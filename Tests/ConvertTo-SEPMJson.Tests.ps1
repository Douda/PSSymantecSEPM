[CmdletBinding()]
param()

Describe 'ConvertTo-SEPMJson' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'PS 7+ path: basic serialization with depth' {
        It 'serializes nested objects at depth > 2 without truncation' {
            InModuleScope PSSymantecSEPM {
                $input = @{ a = @{ b = @{ c = 1 } } }
                $result = ConvertTo-SEPMJson -InputObject $input -Depth 10

                $result | Should -BeExactly '{"a":{"b":{"c":1}}}'
            }
        }
    }

    Context 'PS 5.1 path: recursive StringBuilder serializer' {
        It 'serializes nested objects at depth > 2 without truncation' {
            InModuleScope PSSymantecSEPM {
                Mock Get-PSVersionMajor { return 5 }

                $input = @{ a = @{ b = @{ c = 1 } } }
                $result = ConvertTo-SEPMJson -InputObject $input -Depth 10

                $result | Should -BeExactly '{"a":{"b":{"c":1}}}'
            }
        }
    }

    Context '-AsArray switch' {
        It 'PS 7+: -AsArray wraps single object in JSON array brackets' {
            InModuleScope PSSymantecSEPM {
                $input = [PSCustomObject]@{ key = 'value' }
                $result = ConvertTo-SEPMJson -InputObject $input -Depth 10 -AsArray

                $result | Should -BeExactly '[{"key":"value"}]'
            }
        }

        It 'PS 5.1: -AsArray wraps single object in JSON array brackets' {
            InModuleScope PSSymantecSEPM {
                Mock Get-PSVersionMajor { return 5 }

                $input = [PSCustomObject]@{ key = 'value' }
                $result = ConvertTo-SEPMJson -InputObject $input -Depth 10 -AsArray

                $result | Should -BeExactly '[{"key":"value"}]'
            }
        }

        It '-AsArray with an already-serialized array input preserves array' {
            InModuleScope PSSymantecSEPM {
                $input = @(1, 2, 3)
                $result = ConvertTo-SEPMJson -InputObject $input -Depth 10 -AsArray -Compress

                $result | Should -BeExactly '[[1,2,3]]'
            }
        }
    }

    Context 'Special character escaping' {
        It 'PS 7+: escapes newline, tab, double-quote, and backslash' {
            InModuleScope PSSymantecSEPM {
                # Build test string with embedded special characters
                $lf = [char]10
                $tab = [char]9
                $str = 'a' + $lf + 'b' + $tab + 'c"d\e'
                $input = [PSCustomObject]@{ text = $str }
                $result = ConvertTo-SEPMJson -InputObject $input -Depth 10 -Compress

                # Expected: {"text":"a\nb\tc\"d\\e"}
                $expected = '{"text":"a\nb\tc\"d\\e"}'
                $result | Should -BeExactly $expected
            }
        }

        It 'PS 5.1: escapes newline, tab, double-quote, and backslash' {
            InModuleScope PSSymantecSEPM {
                Mock Get-PSVersionMajor { return 5 }

                $lf = [char]10
                $tab = [char]9
                $str = 'a' + $lf + 'b' + $tab + 'c"d\e'
                $input = [PSCustomObject]@{ text = $str }
                $result = ConvertTo-SEPMJson -InputObject $input -Depth 10 -Compress

                $expected = '{"text":"a\nb\tc\"d\\e"}'
                $result | Should -BeExactly $expected
            }
        }

        It 'PS 5.1: handles null, bool, and numeric values correctly' {
            InModuleScope PSSymantecSEPM {
                Mock Get-PSVersionMajor { return 5 }

                $input = [PSCustomObject]@{
                    nil   = $null
                    yes   = $true
                    no    = $false
                    int   = 42
                    big   = [long]9999999999
                }
                $result = ConvertTo-SEPMJson -InputObject $input -Depth 10

                $result | Should -BeExactly '{"nil":null,"yes":true,"no":false,"int":42,"big":9999999999}'
            }
        }
    }

    Context '-Compress switch' {
        It 'PS 7+: -Compress produces compact JSON (no newlines or indentation)' {
            InModuleScope PSSymantecSEPM {
                $input = [PSCustomObject]@{ a = 1; b = 2 }
                $result = ConvertTo-SEPMJson -InputObject $input -Depth 10 -Compress

                $result | Should -Not -Match '\n'
                $result | Should -Not -Match '  '
                $result | Should -BeExactly '{"a":1,"b":2}'
            }
        }

        It 'PS 5.1: -Compress does not add whitespace (serializer is inherently compact)' {
            InModuleScope PSSymantecSEPM {
                Mock Get-PSVersionMajor { return 5 }

                $input = [PSCustomObject]@{ a = 1; b = 2 }
                $result = ConvertTo-SEPMJson -InputObject $input -Depth 10 -Compress

                $result | Should -Not -Match '\n'
                $result | Should -BeExactly '{"a":1,"b":2}'
            }
        }
    }
}
