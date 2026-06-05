[CmdletBinding()]
param()

# Build & Load the module
$moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
. (Join-Path -Path $moduleRootPath -ChildPath 'Tests/Config/Common-Init.ps1')

Describe 'Get-SEPMAccessToken' {
    InModuleScope PSSymantecSEPM { 
        BeforeAll {
            # This is common test code setup logic for all Pester test files
            $moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests/Config/Common-BeforeAll.ps1')

            # Override file paths to isolate from real config
            $script:configurationFilePath = Join-Path -Path 'TestDrive:' -ChildPath 'config.json'
            $script:credentialsFilePath  = Join-Path -Path 'TestDrive:' -ChildPath 'creds.xml'
            $script:accessTokenFilePath  = Join-Path -Path 'TestDrive:' -ChildPath 'token.xml'

            # Set up configuration so BaseURLv1/v2 are populated
            $script:configuration = [PSCustomObject]@{
                ServerAddress = 'FakeServer01'
                port          = '1234'
                domain        = ''
            }
            $script:BaseURLv1 = 'https://FakeServer01:1234/sepm/api/v1'
            $script:BaseURLv2 = 'https://FakeServer01:1234/sepm/api/v2'
            $script:SkipCert  = $false

            # Mock Test-SEPMAccessToken to return true for valid token
            Mock Test-SEPMAccessToken -ModuleName PSSymantecSEPM { return $true }
        }

        AfterAll {
            # This is common test code teardown logic for all Pester test files
            $moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests/Config/Common-AfterAll.ps1')
        }

        Context 'token provided as parameter' {
            It 'Test Token with parameter' {
                InModuleScope PSSymantecSEPM {
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

                    $pass = ConvertTo-SecureString -String 'FakePassword' -AsPlainText -Force
                    $script:Credential = New-Object System.Management.Automation.PSCredential -ArgumentList 'FakeUser', $pass

                    Mock Test-SEPMAccessToken -ModuleName PSSymantecSEPM { return $true }

                    $token = [PSCustomObject]@{
                        'token' = 'FakeToken'
                    }
                    $result = Get-SEPMAccessToken -AccessToken $token
                    $result | Should -Be $token
                    $script:accessToken | Should -Be $token
                }
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

                # Token file saved on disk
                [PSCustomObject]@{
                    'token'              = 'FakeTokenFromDisk'
                    tokenExpiration      = (Get-Date).AddSeconds(3600)
                    SkipCertificateCheck = $true
                } | Export-Clixml -Path $script:accessTokenFilePath -Force
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

        Context 'query token from SEPM' {
            BeforeAll {
                # Ensure credential is set
                $pass = ConvertTo-SecureString -String 'FakePassword' -AsPlainText -Force
                $script:Credential = New-Object System.Management.Automation.PSCredential -ArgumentList 'FakeUser', $pass

                # Ensure BaseURL is configured in this context
                $script:configuration = [PSCustomObject]@{
                    ServerAddress = 'FakeServer01'
                    port          = '1234'
                    domain        = ''
                }
                $script:BaseURLv1 = 'https://FakeServer01:1234/sepm/api/v1'
                $script:BaseURLv2 = 'https://FakeServer01:1234/sepm/api/v2'

                # No token in memory, forces query to SEPM
                $script:accessToken = $null

                # Invalidate any cached token
                Mock Test-SEPMAccessToken -ModuleName PSSymantecSEPM { return $false }

                $URI_Authenticate = $script:BaseURLv1 + '/identity/authenticate'

                # Mock Invoke-ABRestMethod to return a valid token
                Mock Invoke-ABRestMethod -ModuleName PSSymantecSEPM -ParameterFilter {
                    $params.Method -eq 'POST' -and $params.Uri -eq $URI_Authenticate
                } {
                    return [PSCustomObject]@{
                        'token'         = 'FakeTokenFromSEPM'
                        tokenExpiration = [Int64]'43199'
                    }
                }
            }

            It 'BaseURL Should be configured' {
                $script:BaseURLv1 | Should -Be 'https://FakeServer01:1234/sepm/api/v1'
                $script:BaseURLv2 | Should -Be 'https://FakeServer01:1234/sepm/api/v2'
            }
                

            It 'Returns valid token from SEPM' {
                $result = Get-SEPMAccessToken
                $result | Should -BeOfType [PSCustomObject]
                $result.token | Should -Be 'FakeTokenFromSEPM'
                $result.tokenExpiration | Should -BeOfType [datetime]
            }

            It 'Caches the token in memory' {
                $result = Get-SEPMAccessToken
                $script:accessToken | Should -Be $result
            }

            It 'Stores token in a file on disk as a SecureString' {
                Get-SEPMAccessToken
                $accessTokenContent = Import-Clixml -Path $script:accessTokenFilePath
                $accessTokenContent.token | Should -Be 'FakeTokenFromSEPM'
            }
        }
        
    }
}
