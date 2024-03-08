[CmdletBinding()]
param()

# Build & Load the module
$moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
. (Join-Path -Path $moduleRootPath -ChildPath 'Tests\Config\Common-Init.ps1')

Describe 'Get-SEPMAccessToken' {
    InModuleScope PSSymantecSEPM { 
        BeforeAll {
            # This is common test code setup logic for all Pester test files
            $moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests\Config\Common-BeforeAll.ps1')

            # Load Pester test environment setup
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests\Config\Common-TestEnvironmentSetup.ps1')

            # Mock Test-SEPMAccessToken to return true for valid token
            Mock Test-SEPMAccessToken -ModuleName $script:moduleName { return $true }
        }

        AfterAll {
            # This is common test code teardown logic for all Pester test files
            $moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests\Config\Common-AfterAll.ps1')
        }

        Context 'token provided as parameter' {
            BeforeAll {}

            It 'Test Token with parameter' {
                $token = [PSCustomObject]@{
                    'token' = 'FakeToken'
                }
                $result = Get-SEPMAccessToken -AccessToken $token
                $result | Should -Be $token
                $script:accessToken | Should -Be $token
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
                # Initialize configuration to force query token from SEPM
                $script:accessToken = $null # No token in memory

                # invalid any token already available
                Mock Test-SEPMAccessToken -ModuleName $script:moduleName { return $false }

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