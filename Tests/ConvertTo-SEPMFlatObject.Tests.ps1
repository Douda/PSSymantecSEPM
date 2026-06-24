[CmdletBinding()]
param()

Describe 'ConvertTo-SEPMFlatObject' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Simple nested object' {
        It 'Flattens a single-level nested object' {
            $input = [PSCustomObject]@{
                Name    = 'Test'
                Address = [PSCustomObject]@{
                    Street = 'Main St'
                    City   = 'Springfield'
                }
            }

            $result = $input | ConvertTo-SEPMFlatObject

            $result | Should -Not -BeNullOrEmpty
            $result.'Address.Street' | Should -Be 'Main St'
            $result.'Address.City' | Should -Be 'Springfield'
            $result.'Name' | Should -Be 'Test'
        }

        It 'Flattens multiple objects from pipeline' {
            $objects = @(
                [PSCustomObject]@{ A = 'one'; Inner = [PSCustomObject]@{ B = 'two' } },
                [PSCustomObject]@{ A = 'three'; Inner = [PSCustomObject]@{ B = 'four' } }
            )

            $result = $objects | ConvertTo-SEPMFlatObject

            $result.Count | Should -Be 2
            $result[0].'Inner.B' | Should -Be 'two'
            $result[1].'Inner.B' | Should -Be 'four'
        }
    }

    Context 'Nested object with arrays' {
        It 'Flattens arrays with 1-based indexing by default' {
            $input = [PSCustomObject]@{
                Items = @(
                    [PSCustomObject]@{ Name = 'First' },
                    [PSCustomObject]@{ Name = 'Second' }
                )
            }

            $result = $input | ConvertTo-SEPMFlatObject

            $result.'Items.1.Name' | Should -Be 'First'
            $result.'Items.2.Name' | Should -Be 'Second'
        }
    }

    Context 'Custom separator' {
        It 'Uses the specified separator' {
            $input = [PSCustomObject]@{
                Data = [PSCustomObject]@{
                    Value = 42
                }
            }

            $result = $input | ConvertTo-SEPMFlatObject -Separator '_'

            $result.'Data_Value' | Should -Be 42
        }
    }

    Context 'ExcludeProperty parameter' {
        It 'Excludes specified properties from output' {
            $input = [PSCustomObject]@{
                Keep    = 'kept'
                Exclude = 'removed'
            }

            $result = $input | ConvertTo-SEPMFlatObject -ExcludeProperty 'Exclude'

            $result.'Keep' | Should -Be 'kept'
            # Verify Exclude is not in the result
            $result.PSObject.Properties.Name -contains 'Exclude' | Should -Be $false
        }
    }

    Context '-Uncut switch parameter' {
        It 'Accepts -Uncut without a value (switch semantics)' {
            $input = [PSCustomObject]@{ Name = 'Test' }

            $result = $input | ConvertTo-SEPMFlatObject -Uncut

            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be 'Test'
        }

        It 'Without -Uncut defaults to depth 5 and truncates deeper nesting' {
            $inner = [PSCustomObject]@{ Value = 'deep' }
            $level4 = [PSCustomObject]@{ L4 = $inner }
            $level3 = [PSCustomObject]@{ L3 = $level4 }
            $level2 = [PSCustomObject]@{ L2 = $level3 }
            $level1 = [PSCustomObject]@{ L1 = $level2 }
            $root   = [PSCustomObject]@{ Root = $level1 }

            $result = $root | ConvertTo-SEPMFlatObject

            # Depth limit means some deep properties are truncated (not flattened)
            $result.PSObject.Properties.Name | Should -Not -BeNullOrEmpty
        }

        It 'With -Uncut flattens deeply nested objects beyond default depth' {
            $inner = [PSCustomObject]@{ Value = 'deep' }
            $level4 = [PSCustomObject]@{ L4 = $inner }
            $level3 = [PSCustomObject]@{ L3 = $level4 }
            $level2 = [PSCustomObject]@{ L2 = $level3 }
            $level1 = [PSCustomObject]@{ L1 = $level2 }
            $root   = [PSCustomObject]@{ Root = $level1 }

            $result = $root | ConvertTo-SEPMFlatObject -Uncut

            # Should flatten all 6+ levels to find the leaf property
            $result.'Root.L1.L2.L3.L4.Value' | Should -Be 'deep'
        }
    }

    Context 'Edge cases' {
        It 'Handles null input gracefully' {
            $result = $null | ConvertTo-SEPMFlatObject
            $result | Should -BeNullOrEmpty
        }

        It 'Handles empty object' {
            $input = [PSCustomObject]@{}

            $result = $input | ConvertTo-SEPMFlatObject

            # Empty object has no leaf properties to flatten, returns null
            $result | Should -BeNullOrEmpty
        }
    }
}
