[CmdletBinding()]
param()

Describe 'Get-SEPMThreatStats' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'happy path' {
        It 'returns threat stats with expected properties' {
            $null = Set-TestMocks -Transport {
                return @{
                    Stats = @{
                        lastUpdated     = '1781052202808'
                        infectedClients = '0'
                    }
                }
            }

            $result = Get-SEPMThreatStats
            $result.lastUpdated     | Should -Be '1781052202808'
            $result.infectedClients | Should -Be '0'
        }

        It 'calls the correct API endpoint' {
            $null = Set-TestMocks -Transport { return @{ Stats = @{ ok = $true } } }

            Get-SEPMThreatStats | Out-Null
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'GET' -and $Uri -match '/stats/threat$'
            }
        }
    }
}
