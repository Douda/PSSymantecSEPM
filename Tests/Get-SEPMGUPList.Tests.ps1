[CmdletBinding()]
param()

Describe 'Get-SEPMGUPList' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'happy path' {
        It 'returns GUP list from the API' {
            $null = Set-TestMocks -Transport {
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

            $result = Get-SEPMGUPList
            $result.Count | Should -Be 2
            $result[0].computerName | Should -Be 'Server01'
            $result[0].agentVersion  | Should -Be '12.1.7454.7000'
            $result[1].computerName | Should -Be 'Server02'
        }

        It 'calls the correct API endpoint' {
            $null = Set-TestMocks -Transport { return @() }

            Get-SEPMGUPList | Out-Null
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'GET' -and $Uri -match '/gup/status$'
            }
        }

        It 'handles empty GUP list gracefully' {
            $null = Set-TestMocks -Transport { return @() }

            # Empty API response should not throw
            { Get-SEPMGUPList } | Should -Not -Throw
        }
    }
}
