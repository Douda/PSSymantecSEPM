[CmdletBinding()]
param()

BeforeDiscovery {
    $moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
    . (Join-Path -Path $moduleRootPath -ChildPath 'Tests/Config/Common-Init.ps1')
}

Describe 'Initialize-SEPMSession' {
    Context 'Session creation' {
        BeforeAll {
            InModuleScope PSSymantecSEPM {
                # Override file paths to avoid reading real user tokens
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

                $securePass = ConvertTo-SecureString -String 'FakePassword' -AsPlainText -Force
                $script:Credential = New-Object System.Management.Automation.PSCredential -ArgumentList 'FakeUser', $securePass

                $script:_session = $null
                $script:accessToken = $null

                Mock Test-SEPMAccessToken -ModuleName $script:moduleName { return $false }
                Mock Invoke-ABRestMethod -ModuleName $script:moduleName -ParameterFilter {
                    $params.Method -eq 'POST' -and $params.Uri -match '/identity/authenticate'
                } {
                    return [PSCustomObject]@{
                        token           = 'FakeTokenFromSEPM'
                        tokenExpiration = [Int64]3600
                    }
                }
            }
        }

        It 'returns a [PSCustomObject] with Headers, BaseURLv1, BaseURLv2, SkipCert' {
            InModuleScope PSSymantecSEPM {
                $result = Initialize-SEPMSession
                $result | Should -BeOfType [PSCustomObject]
                $result.Headers | Should -Not -BeNullOrEmpty
                $result.Headers.Authorization | Should -Be 'Bearer FakeTokenFromSEPM'
                $result.Headers.Content | Should -Be 'application/json'
                $result.BaseURLv1 | Should -Be 'https://FakeServer01:1234/sepm/api/v1'
                $result.BaseURLv2 | Should -Be 'https://FakeServer01:1234/sepm/api/v2'
                $result.SkipCert | Should -BeFalse
            }
        }
    }

    Context 'Session caching' {
        BeforeAll {
            InModuleScope PSSymantecSEPM {
                # Override file paths to avoid reading real user tokens
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

                $securePass = ConvertTo-SecureString -String 'FakePassword' -AsPlainText -Force
                $script:Credential = New-Object System.Management.Automation.PSCredential -ArgumentList 'FakeUser', $securePass

                $script:_session = $null
                $script:accessToken = $null
                $script:_mockAuthCallCount = 0

                # Mock token as VALID for caching test
                Mock Test-SEPMAccessToken -ModuleName $script:moduleName { return $true }
                Mock Invoke-ABRestMethod -ModuleName $script:moduleName -ParameterFilter {
                    $params.Method -eq 'POST' -and $params.Uri -match '/identity/authenticate'
                } {
                    $script:_mockAuthCallCount++
                    return [PSCustomObject]@{
                        token           = 'FakeTokenFromSEPM'
                        tokenExpiration = [Int64]3600
                    }
                }
            }
        }

        It 'reuses cached session on second call without re-querying SEPM' {
            InModuleScope PSSymantecSEPM {
                # First call establishes the session (queries SEPM once)
                $session1 = Initialize-SEPMSession
                $session1 | Should -Not -BeNullOrEmpty
                $script:_mockAuthCallCount | Should -Be 1

                # Second call should reuse cached session without querying SEPM again
                $session2 = Initialize-SEPMSession
                $session2 | Should -Be $session1

                # Still exactly one auth call total
                $script:_mockAuthCallCount | Should -Be 1
            }
        }
    }

    Context 'Token expiry renewal' {
        BeforeAll {
            InModuleScope PSSymantecSEPM {
                # Override file paths to avoid reading real user tokens
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

                $securePass = ConvertTo-SecureString -String 'FakePassword' -AsPlainText -Force
                $script:Credential = New-Object System.Management.Automation.PSCredential -ArgumentList 'FakeUser', $securePass

                $script:_session = $null
                $script:accessToken = $null
                $script:_mockAuthCallCount = 0

                Mock Invoke-ABRestMethod -ModuleName $script:moduleName -ParameterFilter {
                    $params.Method -eq 'POST' -and $params.Uri -match '/identity/authenticate'
                } {
                    $script:_mockAuthCallCount++
                    return [PSCustomObject]@{
                        token           = 'FakeTokenFromSEPM'
                        tokenExpiration = [Int64]3600
                    }
                }
            }
        }

        It 'transparently renews when cached token is expired' {
            InModuleScope PSSymantecSEPM {
                # First, set up an expired session cache
                $expiredTokenInfo = [PSCustomObject]@{
                    token           = 'OldExpiredToken'
                    tokenExpiration = (Get-Date).AddHours(-1)
                }
                $script:_session = [PSCustomObject]@{
                    Headers   = @{
                        Authorization = 'Bearer OldExpiredToken'
                        Content       = 'application/json'
                    }
                    BaseURLv1 = $script:BaseURLv1
                    BaseURLv2 = $script:BaseURLv2
                    SkipCert  = $script:SkipCert
                    TokenInfo = $expiredTokenInfo
                }

                # Mock: session token is expired, but new token is valid
                Mock Test-SEPMAccessToken -ModuleName $script:moduleName -ParameterFilter {
                    $TokenInfo.token -eq 'OldExpiredToken'
                } { return $false }
                Mock Test-SEPMAccessToken -ModuleName $script:moduleName -ParameterFilter {
                    $TokenInfo.token -eq 'FakeTokenFromSEPM'
                } { return $true }

                # Call should detect expired session and renew
                $result = Initialize-SEPMSession
                $result | Should -Not -BeNullOrEmpty
                $result.Headers.Authorization | Should -Be 'Bearer FakeTokenFromSEPM'

                # Auth endpoint should have been called once for renewal
                $script:_mockAuthCallCount | Should -Be 1
            }
        }
    }

    Context 'Disk-cached token' {
        BeforeAll {
            InModuleScope PSSymantecSEPM {
                # Override file paths to avoid reading real user tokens
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

                # Clear memory caches to force fallback to disk
                $script:accessToken = $null
                $script:_session   = $null

                # Write token file to TestDrive
                [PSCustomObject]@{
                    token                = 'FakeTokenFromDisk'
                    tokenExpiration      = (Get-Date).AddSeconds(3600)
                    SkipCertificateCheck = $true
                } | Export-Clixml -Path $script:accessTokenFilePath -Force

                Mock Test-SEPMAccessToken -ModuleName $script:moduleName { return $true }
            }
        }

        It 'reads disk-cached token and builds a valid session' {
            InModuleScope PSSymantecSEPM {
                $result = Initialize-SEPMSession
                $result | Should -BeOfType [PSCustomObject]
                $result.Headers.Authorization | Should -Be 'Bearer FakeTokenFromDisk'
                $result.TokenInfo | Should -Not -BeNullOrEmpty
                $result.TokenInfo.token | Should -Be 'FakeTokenFromDisk'
            }
        }

        It 'promotes disk token to script:accessToken after session init' {
            InModuleScope PSSymantecSEPM {
                $null = Initialize-SEPMSession
                $script:accessToken | Should -Not -BeNullOrEmpty
                $script:accessToken.token | Should -Be 'FakeTokenFromDisk'
            }
        }
    }

    Context 'Missing configuration' {
        BeforeAll {
            InModuleScope PSSymantecSEPM {
                # Override file paths to avoid reading real user tokens
                $script:configurationFilePath = Join-Path -Path 'TestDrive:' -ChildPath 'config.json'
                $script:credentialsFilePath  = Join-Path -Path 'TestDrive:' -ChildPath 'creds.xml'
                $script:accessTokenFilePath  = Join-Path -Path 'TestDrive:' -ChildPath 'token.xml'

                # No configuration set — ServerAddress is empty
                $script:configuration = [PSCustomObject]@{
                    ServerAddress = ''
                    port          = '8446'
                    domain        = ''
                }
                $script:BaseURLv1 = $null
                $script:BaseURLv2 = $null
                $script:SkipCert  = $false

                $script:_session = $null
                $script:accessToken = $null

                Mock Test-SEPMAccessToken -ModuleName $script:moduleName { return $false }
            }
        }

        It 'throws an error when configuration is missing' {
            InModuleScope PSSymantecSEPM {
                { Initialize-SEPMSession -ErrorAction Stop } | Should -Throw
            }
        }
    }
}
