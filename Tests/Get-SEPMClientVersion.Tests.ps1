[CmdletBinding()]
param()

Describe 'Get-SEPMClientVersion' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Session-based flow' {
        It 'returns client version list with version and count fields' {
            $null = Set-TestMocks -SkipCert -Transport {
                return @{
                    clientVersionList = @(
                        @{ version = '14.3.558.0000'; clientsCount = 5; formattedVersion = '14.3 (14.3) build 0000' }
                        @{ version = '14.2.1031.0100'; clientsCount = 21; formattedVersion = '14.2.1 (14.2 RU1) build 0100' }
                    )
                }
            }

            $result = Get-SEPMClientVersion
            $result.Count | Should -Be 2
            $result[0].version | Should -Be '14.3.558.0000'
            $result[0].clientsCount | Should -Be 5
            $result[1].version | Should -Be '14.2.1031.0100'
        }

        It 'returns empty array when API returns null list' {
            $null = Set-TestMocks -SkipCert -Transport {
                return @{ clientVersionList = $null }
            }

            $result = Get-SEPMClientVersion
            @($result).Count | Should -Be 0
        }
    }
}
