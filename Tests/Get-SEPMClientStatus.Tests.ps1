[CmdletBinding()]
param()

Describe 'Get-SEPMClientStatus' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Session-based flow' {
        It 'returns client status list with ONLINE and OFFLINE counts' {
            $null = Set-TestMocks -SkipCert -Transport {
                return @{
                    lastUpdated         = 1693910248728
                    clientCountStatsList = @(
                        @{ status = 'ONLINE';  clientsCount = 212 }
                        @{ status = 'OFFLINE'; clientsCount = 48  }
                    )
                }
            }

            $result = Get-SEPMClientStatus
            $result.Count | Should -Be 2
            $result[0].status | Should -Be 'ONLINE'
            $result[0].clientsCount | Should -Be 212
            $result[1].status | Should -Be 'OFFLINE'
        }

        It 'passes session to Invoke-SepmApi' {
            $null = Set-TestMocks -Token 'StatusToken' -Transport {
                return @{ clientCountStatsList = @() }
            }

            Get-SEPMClientStatus | Out-Null
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'GET' -and
                $null -ne $Session -and
                $Session.Headers.Authorization -eq 'Bearer StatusToken'
            }
        }

        It 'returns empty array when API returns null list' {
            $null = Set-TestMocks -SkipCert -Transport {
                return @{ lastUpdated = 1693910248728; clientCountStatsList = $null }
            }

            $result = Get-SEPMClientStatus
            @($result).Count | Should -Be 0
        }
    }
}
