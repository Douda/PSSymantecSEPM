[CmdletBinding()]
param()

Describe 'Get-SEPClientStatus' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Session-based flow' {
        It 'returns client status list with ONLINE and OFFLINE counts' {
            $fakeSession = New-TestSession -SkipCert

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter {
                $Method -eq 'GET' -and $Uri -match '/stats/client/onlinestatus$'
            } {
                return @{
                    lastUpdated         = 1693910248728
                    clientCountStatsList = @(
                        @{ status = 'ONLINE';  clientsCount = 212 }
                        @{ status = 'OFFLINE'; clientsCount = 48  }
                    )
                }
            }

            $result = Get-SEPClientStatus
            $result.Count | Should -Be 2
            $result[0].status | Should -Be 'ONLINE'
            $result[0].clientsCount | Should -Be 212
            $result[1].status | Should -Be 'OFFLINE'
        }

        It 'passes session to Invoke-SepmApi' {
            $fakeSession = New-TestSession -Token 'StatusToken'

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{ clientCountStatsList = @() }
            }

            Get-SEPClientStatus | Out-Null
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'GET' -and
                $null -ne $Session -and
                $Session.Headers.Authorization -eq 'Bearer StatusToken'
            }
        }

        It 'returns empty array when API returns null list' {
            $fakeSession = New-TestSession -SkipCert

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{ lastUpdated = 1693910248728; clientCountStatsList = $null }
            }

            $result = Get-SEPClientStatus
            @($result).Count | Should -Be 0
        }
    }
}
