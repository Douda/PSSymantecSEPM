[CmdletBinding()]
param()

Describe 'Get-SEPMClientDefVersions' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Session-based flow' {
        It 'returns client definition version list' {
            $null = Set-TestMocks -SkipCert -Transport {
                return @{
                    clientDefStatusList = @(
                        @{ version = '2023-09-04 rev. 002'; clientsCount = 15 }
                        @{ version = '2023-09-03 rev. 002'; clientsCount = 4 }
                    )
                }
            }

            $result = Get-SEPMClientDefVersions
            $result.Count | Should -Be 2
            $result[0].version | Should -Be '2023-09-04 rev. 002'
            $result[0].clientsCount | Should -Be 15
        }

        It 'returns empty array when API returns null list' {
            $null = Set-TestMocks -SkipCert -Transport {
                return @{ clientDefStatusList = $null }
            }

            $result = Get-SEPMClientDefVersions
            @($result).Count | Should -Be 0
        }
    }
}
