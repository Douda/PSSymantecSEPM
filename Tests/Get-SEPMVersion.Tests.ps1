[CmdletBinding()]
param()

Describe 'Get-SEPMVersion' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Session-based flow' {
        It 'returns version object with API_SEQUENCE, API_VERSION, and version fields' {
            $fakeSession = New-TestSession -Token 'FakeSessionToken'

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter {
                $Method -eq 'GET' -and $Uri -match '/version$'
            } {
                return @{
                    API_SEQUENCE = '230504014'
                    API_VERSION  = '14.3.7000'
                    version      = '14.3.9816.7000'
                }
            }

            $result = Get-SEPMVersion
            $result.API_SEQUENCE | Should -Be '230504014'
            $result.API_VERSION  | Should -Be '14.3.7000'
            $result.version      | Should -Be '14.3.9816.7000'
        }

        It 'passes the session object to Invoke-SepmApi' {
            $fakeSession = New-TestSession -Token 'FakeSessionToken'

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM { return @{ ok = $true } }

            Get-SEPMVersion | Out-Null
            Should -Invoke Initialize-SEPMSession -ModuleName PSSymantecSEPM -Times 1 -Exactly
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $null -ne $Session -and
                $Session.Headers.Authorization -eq 'Bearer FakeSessionToken'
            }
        }

        It 'passes Session with SkipCert to Invoke-SepmApi' {
            $fakeSession = New-TestSession -SkipCert -Token 'SkipSessionToken'

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM { return @{ ok = $true } }

            Get-SEPMVersion | Out-Null
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $null -ne $Session -and
                $Session.SkipCert -eq $true -and
                $Session.Headers.Authorization -eq 'Bearer SkipSessionToken'
            }
        }
    }
}
