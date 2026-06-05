[CmdletBinding()]
param()

Describe 'Get-SEPMVersion' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment

        InModuleScope PSSymantecSEPM {
            $script:configurationFilePath = Join-Path -Path 'TestDrive:' -ChildPath 'config.json'
            $script:credentialsFilePath   = Join-Path -Path 'TestDrive:' -ChildPath 'creds.xml'
            $script:accessTokenFilePath   = Join-Path -Path 'TestDrive:' -ChildPath 'token.xml'
        }
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Session-based flow' {
        It 'returns version object with API_SEQUENCE, API_VERSION, and version fields' {
            $fakeSession = New-TestSession -Token 'FakeSessionToken'

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-ABRestMethod -ModuleName PSSymantecSEPM -ParameterFilter {
                $params.Method -eq 'GET' -and $params.Uri -match '/version$'
            } {
                return [PSCustomObject]@{
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

        It 'passes headers when Session.SkipCert is $true' {
            $fakeSession = New-TestSession -SkipCert -Token 'SkipSessionToken'

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-ABRestMethod -ModuleName PSSymantecSEPM { return 'OK' }

            Get-SEPMVersion | Out-Null
            Should -Invoke Invoke-ABRestMethod -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $null -ne $params.Session -and
                $params.Session.SkipCert -eq $true -and
                $params.Session.Headers.Authorization -eq 'Bearer SkipSessionToken'
            }
        }

        It 'passes the session object to Invoke-ABRestMethod via $params.Session' {
            $fakeSession = New-TestSession -Token 'FakeSessionToken'

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-ABRestMethod -ModuleName PSSymantecSEPM { return 'OK' }

            Get-SEPMVersion | Out-Null
            Should -Invoke Initialize-SEPMSession -ModuleName PSSymantecSEPM -Times 1 -Exactly
            Should -Invoke Invoke-ABRestMethod -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $null -ne $params.Session -and
                $params.Session.Headers.Authorization -eq 'Bearer FakeSessionToken'
            }
        }
    }
}
