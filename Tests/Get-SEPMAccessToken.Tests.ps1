[CmdletBinding()]
param()

Describe 'Get-SEPMAccessToken' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    BeforeEach {
        # Start every test from a known-clean module state: no cached token, no credential,
        # no cache files, and a configured server so the prompt paths are not reached.
        InModuleScope PSSymantecSEPM {
            $script:_session = $null
            $script:accessToken = $null
            $script:Credential = $null
            $script:configuration.ServerAddress = 'sepm.example.com'
            Remove-Item -Path $script:accessTokenFilePath -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $script:credentialsFilePath -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'resolution order' {
        It 'returns a valid in-memory token without calling the API' {
            InModuleScope PSSymantecSEPM {
                $script:accessToken = [PSCustomObject]@{
                    token           = 'CachedToken'
                    tokenExpiration = (Get-Date).AddHours(1)
                    SkipCert        = $true
                }
                Mock Invoke-SepmApi { throw 'the API must not be called when a valid token is cached' }

                (Get-SEPMAccessToken).token | Should -Be 'CachedToken'
                Should -Invoke Invoke-SepmApi -Times 0 -Exactly
            }
        }

        It 'returns a valid token from the cache file without calling the API' {
            InModuleScope PSSymantecSEPM {
                [PSCustomObject]@{
                    token           = 'FileToken'
                    tokenExpiration = (Get-Date).AddHours(1)
                    SkipCert        = $true
                } | Export-Clixml -Path $script:accessTokenFilePath

                Mock Invoke-SepmApi { throw 'the API must not be called when the cache file is valid' }

                (Get-SEPMAccessToken).token | Should -Be 'FileToken'
                Should -Invoke Invoke-SepmApi -Times 0 -Exactly
            }
        }

        It 'authenticates again when the token has expired' {
            InModuleScope PSSymantecSEPM {
                $script:accessToken = [PSCustomObject]@{
                    token           = 'Expired'
                    tokenExpiration = (Get-Date).AddHours(-1)
                    SkipCert        = $true
                }
                $script:Credential = [PSCredential]::new('user', (ConvertTo-SecureString 'pw' -AsPlainText -Force))

                Mock Invoke-SepmApi { return @{ token = 'FreshToken'; tokenExpiration = 3600 } }

                (Get-SEPMAccessToken).token | Should -Be 'FreshToken'
            }
        }
    }

    Context 'empty or corrupt cached token file' {
        # Regression: a zero-byte cache file used to abort with the opaque
        # "Root element is missing." XmlException, which -ErrorAction Ignore did not suppress.
        It 'discards an empty token file and authenticates again' {
            InModuleScope PSSymantecSEPM {
                Set-Content -Path $script:accessTokenFilePath -Value '' -NoNewline
                $script:Credential = [PSCredential]::new('user', (ConvertTo-SecureString 'pw' -AsPlainText -Force))

                Mock Invoke-SepmApi { return @{ token = 'FreshToken'; tokenExpiration = 3600 } }

                (Get-SEPMAccessToken).token | Should -Be 'FreshToken'
            }
        }

        It 'discards an unreadable token file and authenticates again' {
            InModuleScope PSSymantecSEPM {
                Set-Content -Path $script:accessTokenFilePath -Value 'this is not clixml'
                $script:Credential = [PSCredential]::new('user', (ConvertTo-SecureString 'pw' -AsPlainText -Force))

                Mock Invoke-SepmApi { return @{ token = 'FreshToken'; tokenExpiration = 3600 } }

                (Get-SEPMAccessToken).token | Should -Be 'FreshToken'
            }
        }

        It 'replaces the discarded cache file with a usable one' {
            InModuleScope PSSymantecSEPM {
                Set-Content -Path $script:accessTokenFilePath -Value '' -NoNewline
                $script:Credential = [PSCredential]::new('user', (ConvertTo-SecureString 'pw' -AsPlainText -Force))

                Mock Invoke-SepmApi { return @{ token = 'FreshToken'; tokenExpiration = 3600 } }
                $null = Get-SEPMAccessToken

                (Get-Item -Path $script:accessTokenFilePath).Length | Should -BeGreaterThan 0
            }
        }
    }

    Context 'corrupt credential file' {
        It 'warns and treats the file as absent instead of failing' {
            InModuleScope PSSymantecSEPM {
                Set-Content -Path $script:credentialsFilePath -Value 'not clixml'
                Mock Get-Credential { [PSCredential]::new('prompted', (ConvertTo-SecureString 'pw' -AsPlainText -Force)) }
                Mock Invoke-SepmApi { return @{ token = 'FreshToken'; tokenExpiration = 3600 } }

                $warnings = @()
                $null = Get-SEPMAccessToken -WarningVariable warnings -WarningAction SilentlyContinue

                ($warnings -join ' ') | Should -Match 'credential file'
            }
        }

        It 'ignores an empty credential file' {
            InModuleScope PSSymantecSEPM {
                Set-Content -Path $script:credentialsFilePath -Value '' -NoNewline
                Mock Get-Credential { [PSCredential]::new('prompted', (ConvertTo-SecureString 'pw' -AsPlainText -Force)) }
                Mock Invoke-SepmApi { return @{ token = 'FreshToken'; tokenExpiration = 3600 } }

                $warnings = @()
                $null = Get-SEPMAccessToken -WarningVariable warnings -WarningAction SilentlyContinue

                ($warnings -join ' ') | Should -Match 'credential file'
            }
        }
    }

    Context 'authentication failure' {
        It 'throws SEPM.AuthenticationFailed when the server returns no token' {
            InModuleScope PSSymantecSEPM {
                $script:Credential = [PSCredential]::new('user', (ConvertTo-SecureString 'pw' -AsPlainText -Force))
                # A 2xx response carrying no token: the module must not cache this as success.
                Mock Invoke-SepmApi { return @{ tokenExpiration = 3600 } }

                try {
                    $null = Get-SEPMAccessToken
                    throw 'expected Get-SEPMAccessToken to throw'
                } catch {
                    $_.FullyQualifiedErrorId | Should -BeLike 'SEPM.AuthenticationFailed*'
                }
            }
        }

        It 'does not cache a token when authentication failed' {
            InModuleScope PSSymantecSEPM {
                $script:Credential = [PSCredential]::new('user', (ConvertTo-SecureString 'pw' -AsPlainText -Force))
                Mock Invoke-SepmApi { return @{ tokenExpiration = 3600 } }

                # The failure is terminating, so -ErrorAction does not suppress it.
                try { $null = Get-SEPMAccessToken } catch { }

                $script:accessToken | Should -BeNullOrEmpty
            }
        }

        It 're-tags a transport failure on authenticate as SEPM.AuthenticationFailed' {
            InModuleScope PSSymantecSEPM {
                $script:Credential = [PSCredential]::new('user', (ConvertTo-SecureString 'pw' -AsPlainText -Force))
                Mock Invoke-SepmApi {
                    # SEPM answers a wrong password with a generic 400, so the transport cannot
                    # know this is an authentication problem - Get-SEPMAccessToken does.
                    throw (New-SEPMApiError -Message 'SEPM API POST /sepm/api/v1/identity/authenticate failed (HTTP 400): Account is locked or invalid username, password, or domain.' `
                            -Category ([System.Management.Automation.ErrorCategory]::InvalidData) -Target 'https://sepm')
                }

                try {
                    $null = Get-SEPMAccessToken
                    throw 'expected Get-SEPMAccessToken to throw'
                } catch {
                    $_.FullyQualifiedErrorId | Should -BeLike 'SEPM.AuthenticationFailed*'
                    $_.Exception.Message | Should -Match 'invalid username, password, or domain'
                }
            }
        }

        It 'passes a certificate failure through with its own ErrorId' {
            InModuleScope PSSymantecSEPM {
                $script:Credential = [PSCredential]::new('user', (ConvertTo-SecureString 'pw' -AsPlainText -Force))
                Mock Invoke-SepmApi {
                    throw (New-SEPMApiError -Message 'SEPM API POST /sepm/api/v1/identity/authenticate failed: the TLS certificate could not be validated.' `
                            -ErrorId 'SEPM.CertificateError' `
                            -Category ([System.Management.Automation.ErrorCategory]::SecurityError) -Target 'https://sepm')
                }

                try {
                    $null = Get-SEPMAccessToken
                    throw 'expected Get-SEPMAccessToken to throw'
                } catch {
                    $_.FullyQualifiedErrorId | Should -BeLike 'SEPM.CertificateError*'
                }
            }
        }
    }
}
