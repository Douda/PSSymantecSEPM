[CmdletBinding()]
param()

Describe 'Get-SEPMGroups' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'API dispatch' {
        BeforeEach {
            $null = Set-TestMocks -Transport {
                return @{ content = @(); lastPage = $true; totalPages = 1 }
            }
        }

        It 'delegates to Invoke-SepmEndpoint' {
            Mock Invoke-SepmEndpoint -ModuleName PSSymantecSEPM {
                return @()
            }

            Get-SEPMGroups | Out-Null

            Should -Invoke Invoke-SepmEndpoint -ModuleName PSSymantecSEPM -Exactly 1 -Scope It
        }
    }

    Context 'Response handling' {
        It 'returns groups from the API' {
            $session = Set-TestMocks -Transport {
                return @{
                    content = @(
                        @{ id = 'grp1'; name = 'My Company'; fullPathName = 'My Company' }
                        @{ id = 'grp2'; name = 'Workstations'; fullPathName = 'My Company\Workstations' }
                    )
                    lastPage = $true
                    totalPages = 1
                }
            }

            $result = Get-SEPMGroups
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -Be 2
            $result[0].name | Should -Be 'My Company'
            $result[1].name | Should -Be 'Workstations'
        }

        It 'returns empty array when no groups exist' {
            $session = Set-TestMocks -Transport {
                return @{ content = @(); lastPage = $true; totalPages = 1 }
            }

            $result = Get-SEPMGroups
            $result | Should -BeNullOrEmpty
        }

        It 'preserves collection type for single-element results' {
            $session = Set-TestMocks -Transport {
                return @{
                    content = @(
                        @{ id = 'grp1'; name = 'My Company'; fullPathName = 'My Company' }
                    )
                    lastPage = $true
                    totalPages = 1
                }
            }

            $result = Get-SEPMGroups
            $result | Should -Not -BeNullOrEmpty
        }
    }
}
