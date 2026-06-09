[CmdletBinding()]
param()

Describe 'Get-SEPGUPList' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'happy path' {
        BeforeAll {
            $fakeSession = New-TestSession
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
        }

        It 'returns GUP list from the API' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @(
                    @{
                        computerName  = 'Server01'
                        agentVersion  = '12.1.7454.7000'
                        ipAddress     = '10.0.0.150'
                        port          = 2967
                    },
                    @{
                        computerName  = 'Server02'
                        agentVersion  = '14.3.558.0000'
                        ipAddress     = '10.1.0.150'
                        port          = 2967
                    }
                )
            }

            $result = Get-SEPGUPList
            $result.Count | Should -Be 2
            $result[0].computerName | Should -Be 'Server01'
            $result[0].agentVersion  | Should -Be '12.1.7454.7000'
            $result[1].computerName | Should -Be 'Server02'
        }

        It 'calls the correct API endpoint' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM { return @() }

            Get-SEPGUPList | Out-Null
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'GET' -and $Uri -match '/gup/status$'
            }
        }

        It 'handles empty GUP list gracefully' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM { return @() }

            # Empty API response should not throw
            { Get-SEPGUPList } | Should -Not -Throw
        }
    }
}
