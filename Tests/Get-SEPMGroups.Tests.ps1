[CmdletBinding()]
param()

Describe 'Get-SEPMGroups' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
        $script:fakeSession = New-TestSession -SkipCert
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    BeforeEach {
        Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $script:fakeSession }
    }

    Context 'API dispatch' {
        It 'delegates to Invoke-SepmEndpoint' {
            Mock Invoke-SepmEndpoint -ModuleName PSSymantecSEPM {
                return @{ content = @(); lastPage = $true }
            }

            Get-SEPMGroups | Out-Null

            Should -Invoke Invoke-SepmEndpoint -ModuleName PSSymantecSEPM -Exactly 1 -Scope It
        }
    }

    Context 'Response handling' {
        It 'returns groups from the API' {
            Mock Invoke-SepmEndpoint -ModuleName PSSymantecSEPM {
                return @{
                    content   = @(
                        @{ id = 'grp1'; name = 'My Company'; fullPathName = 'My Company' }
                        @{ id = 'grp2'; name = 'Workstations'; fullPathName = 'My Company\Workstations' }
                    )
                    lastPage = $true
                }
            }

            $result = Get-SEPMGroups
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -Be 2
            $result[0].name | Should -Be 'My Company'
            $result[1].name | Should -Be 'Workstations'
        }

        It 'returns empty array when no groups exist' {
            Mock Invoke-SepmEndpoint -ModuleName PSSymantecSEPM {
                return @{ content = @(); lastPage = $true }
            }

            $result = Get-SEPMGroups
            @($result).Count | Should -Be 0
        }

        It 'preserves collection type for single-element results' {
            Mock Invoke-SepmEndpoint -ModuleName PSSymantecSEPM {
                return @{
                    content   = @(
                        @{ id = 'grp1'; name = 'My Company'; fullPathName = 'My Company' }
                    )
                    lastPage = $true
                }
            }

            $result = Get-SEPMGroups
            @($result).Count | Should -Be 1
            $result.Count | Should -Be 1
        }
    }
}
