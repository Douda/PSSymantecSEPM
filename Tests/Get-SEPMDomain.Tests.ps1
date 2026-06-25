[CmdletBinding()]
param()

Describe 'Get-SEPMDomain' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Session-based flow' {
        It 'returns domain list from the API' {
            $null = Set-TestMocks -SkipCert -Transport {
                return @(
                    @{ id = 'abc123'; name = 'Default'; description = ''; createdTime = 1360247301316; enable = $true }
                    @{ id = 'def456'; name = 'Secondary'; description = 'test'; createdTime = 1360247301317; enable = $false }
                )
            }

            $result = Get-SEPMDomain
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 2
            $result[0].name | Should -Be 'Default'
            $result[1].name | Should -Be 'Secondary'
        }

        It 'passes session to Invoke-SepmApi' {
            $null = Set-TestMocks -Token 'DomainToken' -Transport { return @() }

            Get-SEPMDomain | Out-Null
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'GET' -and
                $null -ne $Session -and
                $Session.Headers.Authorization -eq 'Bearer DomainToken'
            }
        }
    }
}
