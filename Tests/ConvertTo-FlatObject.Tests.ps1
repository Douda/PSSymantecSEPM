[CmdletBinding()]
param()

Describe 'ConvertTo-FlatObject' {
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

            $result = $input | ConvertTo-FlatObject

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

            $result = $objects | ConvertTo-FlatObject

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

            $result = $input | ConvertTo-FlatObject

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

            $result = $input | ConvertTo-FlatObject -Separator '_'

            $result.'Data_Value' | Should -Be 42
        }
    }

    Context 'ExcludeProperty parameter' {
        It 'Excludes specified properties from output' {
            $input = [PSCustomObject]@{
                Keep    = 'kept'
                Exclude = 'removed'
            }

            $result = $input | ConvertTo-FlatObject -ExcludeProperty 'Exclude'

            $result.'Keep' | Should -Be 'kept'
            # Verify Exclude is not in the result
            $result.PSObject.Properties.Name -contains 'Exclude' | Should -Be $false
        }
    }

    Context 'Edge cases' {
        It 'Handles null input gracefully' {
            $result = $null | ConvertTo-FlatObject
            $result | Should -BeNullOrEmpty
        }

        It 'Handles empty object' {
            $input = [PSCustomObject]@{}

            $result = $input | ConvertTo-FlatObject

            # Empty object has no leaf properties to flatten, returns null
            $result | Should -BeNullOrEmpty
        }
    }
}
