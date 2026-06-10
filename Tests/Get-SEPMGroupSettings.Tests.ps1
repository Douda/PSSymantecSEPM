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
            $fakeSession = New-TestSession -SkipCert

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter {
                $Method -eq 'GET' -and $Uri -match '/groups/grp123/locations/loc456/settings$'
            } {
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
            $fakeSession = New-TestSession -Token 'GroupSettingsToken'

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM { return @{ ok = $true } }

            Get-SEPMGroupSettings -groupId 'grp123' -locationId 'loc456' | Out-Null
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'GET' -and
                $null -ne $Session -and
                $Session.Headers.Authorization -eq 'Bearer GroupSettingsToken'
            }
        }
    }
}
