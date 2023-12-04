[CmdletBinding()]
param()

# Build & Load the module
$moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
. (Join-Path -Path $moduleRootPath -ChildPath 'Tests\Common-Init.ps1')

Describe 'Get-SEPMAccessToken' {
    InModuleScope PSSymantecSEPM { 
        BeforeAll {
            # This is common test code setup logic for all Pester test files
            $moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests\Common-BeforeAll.ps1')
        }

        AfterAll {
            # This is common test code teardown logic for all Pester test files
            $moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests\Common-AfterAll.ps1')
        }

        Context 'When the configuration file exist' {
            BeforeAll {
                # Replace all files with mock files
                $script:configurationFilePath = Join-Path -Path 'TestDrive:' -ChildPath 'config.xml'
                $script:credentialsFilePath = Join-Path -Path 'TestDrive:' -ChildPath 'creds.xml'
                $script:accessTokenFilePath = Join-Path -Path 'TestDrive:' -ChildPath 'token.xml'

                # Configuration file content
                [PSCustomObject]@{
                    'ServerAddress' = 'FakeServer01'
                    'port'          = '1234'
                    'domain'        = ''
                } | Export-Clixml -Path $script:configurationFilePath -Force

                # Credential file content | Fakeuser / FakePassword
                $creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'FakeUser', (ConvertTo-SecureString -String 'FakePassword' -AsPlainText -Force)
                $creds | Export-Clixml -Path $script:credentialsFilePath -Force

                # Token file content
                [PSCustomObject]@{
                    'token'              = 'FakeToken'
                    tokenExpiration      = (Get-Date).AddSeconds(3600)
                    SkipCertificateCheck = $true
                } | Export-Clixml -Path $script:accessTokenFilePath -Force
            }
            Context 'token provided as parameter' {
                BeforeAll {
                    Mock Test-SEPMAccessToken -ModuleName $script:moduleName { return $true }
                }

                It 'Test Token with parameter' {
                    $token = [PSCustomObject]@{
                        'token' = 'FakeToken'
                    }
                    $result = Get-SEPMAccessToken -AccessToken $token
                    $result | Should -Be $token
                }
            }

            Context 'token cached in memory' {
                BeforeAll {
                    # Mocked token in memory
                    $script:accessToken = [PSCustomObject]@{
                        'token'              = 'FakeTokenFromMemory'
                        tokenExpiration      = (Get-Date).AddSeconds(3600)
                        SkipCertificateCheck = $true
                    }

                    # Mock Test-SEPMAccessToken to return true for valid token
                    Mock Test-SEPMAccessToken -ModuleName $script:moduleName { return $true }
                }

                It 'Returns valid token from memory' {
                    $result = Get-SEPMAccessToken
                    $result | Should -Be $script:accessToken
                    $result | Should -BeOfType [PSCustomObject]
                    $result.token | Should -Be 'FakeTokenFromMemory'
                    $result.tokenExpiration | Should -BeOfType [DateTime]
                    $result.SkipCertificateCheck | Should -BeOfType [Boolean]
                }
            }

            Context 'token cached in disk' {
                BeforeAll {
                    # No token in memory will force to look in disk
                    $script:accessToken = $null

                    # Mocked token file
                    $script:accessTokenFilePath = Join-Path -Path 'TestDrive:' -ChildPath 'token.xml'

                    # Token file content converted to xml
                    [PSCustomObject]@{
                        'token'              = 'FakeTokenFromDisk'
                        tokenExpiration      = (Get-Date).AddSeconds(3600)
                        SkipCertificateCheck = $true
                    } | Export-Clixml -Path $script:accessTokenFilePath -Force

                    # Mock Test-SEPMAccessToken to return true for valid token
                    Mock Test-SEPMAccessToken -ModuleName $script:moduleName { return $true }
                }

                It 'Returns valid token from disk' {
                    $result = Get-SEPMAccessToken
                    $result | Should -Be $script:accessToken
                    $result | Should -BeOfType [PSCustomObject]
                    $result.token | Should -Be 'FakeTokenFromDisk'
                    $result.tokenExpiration | Should -BeOfType [DateTime]
                    $result.SkipCertificateCheck | Should -BeOfType [Boolean]
                }
            }

            # TODO not working - Investigate
            Context 'query token from SEPM' {
                BeforeAll {
                    # Initialize configuration to force query token from SEPM
                    $script:accessToken = $null # No token in memory

                    # invalid any token already available
                    Mock Test-SEPMAccessToken -ModuleName $script:moduleName { return $false }

                    # SEPM configuration object loaded
                    $script:configuration = [PSCustomObject]@{
                        'ServerAddress' = 'FakeServer01'
                        'port'          = '1234'
                        'domain'        = ''
                    }

                    # SEPM URL
                    $script:BaseURLv1 = "https://" + $script:configuration.ServerAddress + ":" + $script:configuration.port + "/sepm/api/v1"
                    $script:BaseURLv2 = "https://" + $script:configuration.ServerAddress + ":" + $script:configuration.port + "/sepm/api/v2"

                    # Mock Import-Clixml to return the credential file content
                    # Mock Import-Clixml -ModuleName $script:moduleName -ParameterFilter { $Path -eq $script:credentialsFilePath -and $ErrorAction -eq 'Ignore' } { return $creds }

                    # Mock Test-SEPMCertificate to return true for valid certificate
                    Mock Test-SEPMCertificate -ModuleName $script:moduleName -ParameterFilter { $URI -eq $URI_Authenticate } {}

                    # Mock Invoke-ABRestMethod to return a valid token
                    Mock Invoke-ABRestMethod -ModuleName $script:moduleName -ParameterFilter { $params -eq $Params } {
                        return [PSCustomObject]@{
                            'token'         = 'FakeTokenFromSEPM'
                            tokenExpiration = [Int64]'43199' # random up to 44k
                        }
                    }
                }

                Context 'SEPM URL' {
                    It 'BaseURL Should be configured' {
                        $script:BaseURLv1 | Should -Be 'https://FakeServer01:1234/sepm/api/v1'
                        $script:BaseURLv2 | Should -Be 'https://FakeServer01:1234/sepm/api/v2'
                    }
                }

                Context 'SEPM query' {
                    # It 'Invoke-ABRestMethod should be called' {
                    #     Get-SEPMAccessToken
                    #     Assert-MockCalled Invoke-ABRestMethod -Times 1 -Exactly
                    # }

                    It 'Returns valid token from SEPM' {
                        $result = Get-SEPMAccessToken
                        $result | Should -BeOfType [PSCustomObject]
                        $result.token | Should -Be 'FakeTokenFromSEPM'
                        $result.tokenExpiration | Should -BeOfType [datetime]
                    }
                }
            }
        }
    }
}