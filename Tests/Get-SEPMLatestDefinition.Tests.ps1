[CmdletBinding()]
param()

Describe 'Get-SEPMLatestDefinition' {
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

        It 'returns latest definition info with expected keys' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{
                    contentName         = 'AV_DEFS'
                    publishedBySymantec = '6/9/2026 rev. 2'
                    publishedBySEPM     = '6/8/2026 rev. 23'
                }
            }

            $result = Get-SEPMLatestDefinition
            $result.contentName         | Should -Be 'AV_DEFS'
            $result.publishedBySymantec | Should -Be '6/9/2026 rev. 2'
            $result.publishedBySEPM     | Should -Be '6/8/2026 rev. 23'
        }

        It 'calls the correct API endpoint' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM { return @{ ok = $true } }

            Get-SEPMLatestDefinition | Out-Null
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'GET' -and $Uri -match '/content/avdef/latest$'
            }
        }
    }
}
