[CmdletBinding()]
param()

Describe 'Test-SEPMAccessToken' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'explicit token' {
        It 'returns $true for a token that has not expired' {
            InModuleScope PSSymantecSEPM {
                $token = [PSCustomObject]@{ token = 't'; tokenExpiration = (Get-Date).AddMinutes(5) }
                Test-SEPMAccessToken -Token $token | Should -BeTrue
            }
        }

        It 'returns $false for a token that has expired' {
            InModuleScope PSSymantecSEPM {
                $token = [PSCustomObject]@{ token = 't'; tokenExpiration = (Get-Date).AddMinutes(-5) }
                Test-SEPMAccessToken -Token $token | Should -BeFalse
            }
        }

        It 'returns $false for a token one second past expiry' {
            InModuleScope PSSymantecSEPM {
                $token = [PSCustomObject]@{ token = 't'; tokenExpiration = (Get-Date).AddSeconds(-1) }
                Test-SEPMAccessToken -Token $token | Should -BeFalse
            }
        }

        It 'accepts the Token and AccessToken aliases' {
            InModuleScope PSSymantecSEPM {
                $token = [PSCustomObject]@{ token = 't'; tokenExpiration = (Get-Date).AddMinutes(5) }
                Test-SEPMAccessToken -Token $token       | Should -BeTrue
                Test-SEPMAccessToken -AccessToken $token | Should -BeTrue
            }
        }
    }

    Context 'cached token (no argument)' {
        It 'returns $true when the cached token is still valid' {
            InModuleScope PSSymantecSEPM {
                $script:accessToken = [PSCustomObject]@{ token = 'cached'; tokenExpiration = (Get-Date).AddMinutes(5) }
                Test-SEPMAccessToken | Should -BeTrue
            }
        }

        It 'returns $false when the cached token has expired' {
            InModuleScope PSSymantecSEPM {
                $script:accessToken = [PSCustomObject]@{ token = 'cached'; tokenExpiration = (Get-Date).AddMinutes(-5) }
                Test-SEPMAccessToken | Should -BeFalse
            }
        }

        It 'returns $false when nothing is cached' {
            InModuleScope PSSymantecSEPM {
                $script:accessToken = $null
                Test-SEPMAccessToken | Should -BeFalse
            }
        }
    }

    Context 'null input' {
        It 'returns $false rather than throwing when handed $null' {
            InModuleScope PSSymantecSEPM {
                $script:accessToken = $null
                Test-SEPMAccessToken -Token $null | Should -BeFalse
            }
        }
    }
}
