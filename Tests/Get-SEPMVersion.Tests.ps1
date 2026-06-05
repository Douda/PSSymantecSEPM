[CmdletBinding()]
param()

# Build & Load the module
$moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
. (Join-Path -Path $moduleRootPath -ChildPath 'Tests/Config/Common-Init.ps1')

Describe 'Get-SEPMVersion' {
    Context 'Session-based flow' {
        It 'returns version object with API_SEQUENCE, API_VERSION, and version fields' {
            InModuleScope PSSymantecSEPM {
                $script:configurationFilePath = Join-Path -Path 'TestDrive:' -ChildPath 'config.json'
                $script:credentialsFilePath  = Join-Path -Path 'TestDrive:' -ChildPath 'creds.xml'
                $script:accessTokenFilePath  = Join-Path -Path 'TestDrive:' -ChildPath 'token.xml'

                $script:fakeSession = [PSCustomObject]@{
                    Headers   = @{ Authorization = 'Bearer FakeSessionToken'; Content = 'application/json' }
                    BaseURLv1 = 'https://FakeServer01:1234/sepm/api/v1'
                    BaseURLv2 = 'https://FakeServer01:1234/sepm/api/v2'
                    SkipCert  = $false
                    TokenInfo = [PSCustomObject]@{
                        token           = 'FakeSessionToken'
                        tokenExpiration = (Get-Date).AddHours(1)
                    }
                }

                Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $script:fakeSession }
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
        }

        It 'passes headers when Session.SkipCert is $true' {
            InModuleScope PSSymantecSEPM {
                $script:configurationFilePath = Join-Path -Path 'TestDrive:' -ChildPath 'config.json'
                $script:credentialsFilePath  = Join-Path -Path 'TestDrive:' -ChildPath 'creds.xml'
                $script:accessTokenFilePath  = Join-Path -Path 'TestDrive:' -ChildPath 'token.xml'

                $script:fakeSession = [PSCustomObject]@{
                    Headers   = @{ Authorization = 'Bearer SkipSessionToken'; Content = 'application/json' }
                    BaseURLv1 = 'https://FakeServer01:1234/sepm/api/v1'
                    BaseURLv2 = 'https://FakeServer01:1234/sepm/api/v2'
                    SkipCert  = $true
                    TokenInfo = [PSCustomObject]@{
                        token           = 'SkipSessionToken'
                        tokenExpiration = (Get-Date).AddHours(1)
                    }
                }

                Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $script:fakeSession }
                Mock Invoke-ABRestMethod -ModuleName PSSymantecSEPM { return 'OK' }

                Get-SEPMVersion | Out-Null
                Assert-MockCalled Invoke-ABRestMethod -ModuleName PSSymantecSEPM -Exactly 1 -Scope It -ParameterFilter {
                    $null -ne $params.Session -and
                    $params.Session.SkipCert -eq $true -and
                    $params.Session.Headers.Authorization -eq 'Bearer SkipSessionToken'
                }
            }
        }

        It 'passes the session object to Invoke-ABRestMethod via $params.Session' {
            InModuleScope PSSymantecSEPM {
                $script:configurationFilePath = Join-Path -Path 'TestDrive:' -ChildPath 'config.json'
                $script:credentialsFilePath  = Join-Path -Path 'TestDrive:' -ChildPath 'creds.xml'
                $script:accessTokenFilePath  = Join-Path -Path 'TestDrive:' -ChildPath 'token.xml'

                $script:fakeSession = [PSCustomObject]@{
                    Headers   = @{ Authorization = 'Bearer FakeSessionToken'; Content = 'application/json' }
                    BaseURLv1 = 'https://FakeServer01:1234/sepm/api/v1'
                    BaseURLv2 = 'https://FakeServer01:1234/sepm/api/v2'
                    SkipCert  = $false
                    TokenInfo = [PSCustomObject]@{
                        token           = 'FakeSessionToken'
                        tokenExpiration = (Get-Date).AddHours(1)
                    }
                }

                Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $script:fakeSession }
                Mock Invoke-ABRestMethod -ModuleName PSSymantecSEPM { return 'OK' }

                Get-SEPMVersion | Out-Null
                Assert-MockCalled Initialize-SEPMSession -ModuleName PSSymantecSEPM -Exactly 1 -Scope It
                Assert-MockCalled Invoke-ABRestMethod -ModuleName PSSymantecSEPM -Exactly 1 -Scope It -ParameterFilter {
                    $null -ne $params.Session -and
                    $params.Session.Headers.Authorization -eq 'Bearer FakeSessionToken'
                }
            }
        }
    }
}
