[CmdletBinding()]
param()

Describe 'Invoke-ABRestMethod' {
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

    Context 'Session object provided' {
        BeforeAll {
            InModuleScope PSSymantecSEPM {
                $script:configuration = [PSCustomObject]@{
                    ServerAddress = 'FakeServer01'
                    port          = '1234'
                    domain        = ''
                }
                $script:BaseURLv1 = 'https://FakeServer01:1234/sepm/api/v1'
                $script:BaseURLv2 = 'https://FakeServer01:1234/sepm/api/v2'
                $script:SkipCert  = $false

                $script:fakeSession = New-TestSession -Token 'FakeSessionToken'

                Mock Invoke-RestMethod -ModuleName PSSymantecSEPM { return 'OK' }
            }
        }

        It 'uses Session.Headers as the Authorization header for the API call' {
            InModuleScope PSSymantecSEPM {
                $params = @{
                    Method  = 'GET'
                    Uri     = 'https://FakeServer01:1234/sepm/api/v1/computers'
                    Session = $script:fakeSession
                }
                $result = Invoke-ABRestMethod -params $params
                $result | Should -Be 'OK'

                Should -Invoke Invoke-RestMethod -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                    $Headers.Authorization -eq 'Bearer FakeSessionToken' -and
                    $Headers.Content -eq 'application/json'
                }
            }
        }
    }

    Context 'Certificate skipping with Session.SkipCert = $true' {
        BeforeAll {
            InModuleScope PSSymantecSEPM {
                Mock Invoke-RestMethod -ModuleName PSSymantecSEPM { return 'OK' }
                Mock Skip-Cert -ModuleName PSSymantecSEPM {}
            }
        }

        It 'passes headers and avoids Skip-Cert on PS 7+ when SkipCert is $true' {
            InModuleScope PSSymantecSEPM {
                $sessionWithSkip = New-TestSession -SkipCert -Token 'SkipToken'

                $params = @{
                    Method  = 'GET'
                    Uri     = 'https://FakeServer01:1234/sepm/api/v1/computers'
                    Session = $sessionWithSkip
                }
                $result = Invoke-ABRestMethod -params $params
                $result | Should -Be 'OK'

                Should -Invoke Invoke-RestMethod -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                    $Headers.Authorization -eq 'Bearer SkipToken'
                }
                if ($PSVersionTable.PSVersion.Major -ge 6) {
                    Should -Invoke Skip-Cert -ModuleName PSSymantecSEPM -Times 0 -Exactly
                } else {
                    Should -Invoke Skip-Cert -ModuleName PSSymantecSEPM -Times 1 -Exactly
                }
            }
        }
    }

    Context 'Backward compatibility: no Session provided' {
        BeforeAll {
            InModuleScope PSSymantecSEPM {
                Mock Invoke-RestMethod -ModuleName PSSymantecSEPM { return 'OK' }
                Mock Skip-Cert -ModuleName PSSymantecSEPM {}
            }
        }

        It 'falls back to script:SkipCert = $false when Session is absent' {
            InModuleScope PSSymantecSEPM {
                $script:SkipCert = $false

                $params = @{
                    Method  = 'GET'
                    Uri     = 'https://FakeServer01:1234/sepm/api/v1/computers'
                    headers = @{ 'CustomHeader' = 'Value' }
                }
                $result = Invoke-ABRestMethod -params $params
                $result | Should -Be 'OK'

                Should -Invoke Invoke-RestMethod -ModuleName PSSymantecSEPM -Times 1 -Exactly
            }
        }

        It 'falls back to script:SkipCert = $true when Session is absent' {
            InModuleScope PSSymantecSEPM {
                $script:SkipCert = $true

                $params = @{
                    Method  = 'GET'
                    Uri     = 'https://FakeServer01:1234/sepm/api/v1/computers'
                    headers = @{ 'CustomHeader' = 'Value' }
                }
                $result = Invoke-ABRestMethod -params $params
                $result | Should -Be 'OK'

                Should -Invoke Invoke-RestMethod -ModuleName PSSymantecSEPM -Times 1 -Exactly
            }
        }
    }
}
