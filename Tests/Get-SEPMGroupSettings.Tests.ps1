[CmdletBinding()]
param()

Describe 'Get-SEPMGroupSettings' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Session-based flow' {
        It 'returns group settings for a given location and group' {
            $null = Set-TestMocks -SkipCert -Transport {
                return @{
                    id   = 'settings-1'
                    name = 'Default Settings'
                    configuration = @{ key1 = 'value1' }
                }
            }

            $result = Get-SEPMGroupSettings -groupId 'grp123' -locationId 'loc456'
            $result | Should -Not -BeNullOrEmpty
            $result.name | Should -Be 'Default Settings'
            $result.configuration.key1 | Should -Be 'value1'
        }

        It 'passes session to Invoke-SepmApi' {
            $null = Set-TestMocks -Token 'GroupSettingsToken' -Transport { return @{ ok = $true } }

            Get-SEPMGroupSettings -groupId 'grp123' -locationId 'loc456' | Out-Null
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'GET' -and
                $null -ne $Session -and
                $Session.Headers.Authorization -eq 'Bearer GroupSettingsToken'
            }
        }
    }
}
