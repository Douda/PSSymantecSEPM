[CmdletBinding()]
param()

# Build & Load the module
$moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
. (Join-Path -Path $moduleRootPath -ChildPath 'Tests\Config\Common-Init.ps1')

Describe 'Invoke-ABRestMethod' {
    InModuleScope PSSymantecSEPM {
        BeforeAll {
            # Override file paths to isolate from real config
            $script:configurationFilePath = Join-Path -Path 'TestDrive:' -ChildPath 'config.json'
            $script:credentialsFilePath  = Join-Path -Path 'TestDrive:' -ChildPath 'creds.xml'
            $script:accessTokenFilePath  = Join-Path -Path 'TestDrive:' -ChildPath 'token.xml'

            $script:configuration = [PSCustomObject]@{
                ServerAddress = 'FakeServer01'
                port          = '1234'
                domain        = ''
            }
            $script:BaseURLv1 = 'https://FakeServer01:1234/sepm/api/v1'
            $script:BaseURLv2 = 'https://FakeServer01:1234/sepm/api/v2'
            $script:SkipCert  = $false
        }

        Context 'Session object provided' {
            BeforeAll {
                $script:fakeSession = [PSCustomObject]@{
                    Headers   = @{
                        Authorization = 'Bearer FakeSessionToken'
                        Content       = 'application/json'
                    }
                    BaseURLv1 = 'https://FakeServer01:1234/sepm/api/v1'
                    BaseURLv2 = 'https://FakeServer01:1234/sepm/api/v2'
                    SkipCert  = $false
                    TokenInfo = [PSCustomObject]@{
                        token           = 'FakeSessionToken'
                        tokenExpiration = (Get-Date).AddHours(1)
                    }
                }

                Mock Invoke-RestMethod -ModuleName $script:moduleName { return 'OK' }
            }

            It 'uses Session.Headers as the Authorization header for the API call' {
                $params = @{
                    Method  = 'GET'
                    Uri     = 'https://FakeServer01:1234/sepm/api/v1/computers'
                    Session = $script:fakeSession
                }
                $result = Invoke-ABRestMethod -params $params
                $result | Should -Be 'OK'

                Assert-MockCalled Invoke-RestMethod -ModuleName $script:moduleName -Exactly 1 -Scope It -ParameterFilter {
                    $Headers.Authorization -eq 'Bearer FakeSessionToken' -and
                    $Headers.Content -eq 'application/json'
                }
            }
        }

        Context 'Certificate skipping with Session.SkipCert = $true' {
            BeforeAll {
                Mock Invoke-RestMethod -ModuleName $script:moduleName { return 'OK' }
                # Mock Skip-Cert so we can verify it is NOT called on PS 7+
                Mock Skip-Cert -ModuleName $script:moduleName {}
            }

            It 'passes headers and avoids Skip-Cert on PS 7+ when SkipCert is $true' {
                $sessionWithSkip = [PSCustomObject]@{
                    Headers   = @{
                        Authorization = 'Bearer SkipToken'
                        Content       = 'application/json'
                    }
                    BaseURLv1 = 'https://FakeServer01:1234/sepm/api/v1'
                    BaseURLv2 = 'https://FakeServer01:1234/sepm/api/v2'
                    SkipCert  = $true
                    TokenInfo = [PSCustomObject]@{
                        token           = 'SkipToken'
                        tokenExpiration = (Get-Date).AddHours(1)
                    }
                }

                $params = @{
                    Method  = 'GET'
                    Uri     = 'https://FakeServer01:1234/sepm/api/v1/computers'
                    Session = $sessionWithSkip
                }
                $result = Invoke-ABRestMethod -params $params
                $result | Should -Be 'OK'

                Assert-MockCalled Invoke-RestMethod -ModuleName $script:moduleName -Exactly 1 -Scope It -ParameterFilter {
                    $Headers.Authorization -eq 'Bearer SkipToken'
                }
                # On PS 7+: -SkipCertificateCheck is used, Skip-Cert is NOT called
                # On PS 5.1: Skip-Cert IS called. The assertion below is runtime-aware.
                if ($PSVersionTable.PSVersion.Major -ge 6) {
                    Assert-MockCalled Skip-Cert -ModuleName $script:moduleName -Exactly 0 -Scope It
                } else {
                    Assert-MockCalled Skip-Cert -ModuleName $script:moduleName -Exactly 1 -Scope It
                }
            }
        }

        Context 'Backward compatibility: no Session provided' {
            BeforeAll {
                Mock Invoke-RestMethod -ModuleName $script:moduleName { return 'OK' }
                Mock Skip-Cert -ModuleName $script:moduleName {}
            }

            It 'falls back to script:SkipCert = $false when Session is absent' {
                $script:SkipCert = $false

                $params = @{
                    Method  = 'GET'
                    Uri     = 'https://FakeServer01:1234/sepm/api/v1/computers'
                    headers = @{ 'CustomHeader' = 'Value' }
                }
                $result = Invoke-ABRestMethod -params $params
                $result | Should -Be 'OK'

                Assert-MockCalled Invoke-RestMethod -ModuleName $script:moduleName -Exactly 1 -Scope It
            }

            It 'falls back to script:SkipCert = $true when Session is absent' {
                $script:SkipCert = $true

                $params = @{
                    Method  = 'GET'
                    Uri     = 'https://FakeServer01:1234/sepm/api/v1/computers'
                    headers = @{ 'CustomHeader' = 'Value' }
                }
                $result = Invoke-ABRestMethod -params $params
                $result | Should -Be 'OK'

                Assert-MockCalled Invoke-RestMethod -ModuleName $script:moduleName -Exactly 1 -Scope It
            }
        }
    }
}
