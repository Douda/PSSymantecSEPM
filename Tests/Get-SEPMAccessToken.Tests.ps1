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
        }

        AfterAll {
            # This is common test code teardown logic for all Pester test files
            $moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests/Config/Common-AfterAll.ps1')
        }

        Context 'token provided as parameter (internal-only path)' {
            It 'returns token directly when passed as parameter' {
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

        Context 'token cached in memory — via Initialize-SEPMSession' {
            BeforeAll {
                # Set token in memory but clear session cache to force Initialize-SEPMSession
                # to call Get-SEPMAccessToken, which should pick up $script:accessToken
                $script:accessToken = [PSCustomObject]@{
                    'token'              = 'FakeTokenFromMemory'
                    tokenExpiration      = (Get-Date).AddSeconds(3600)
                    SkipCertificateCheck = $true
                }
                $script:_session = $null

                Mock Test-SEPMAccessToken -ModuleName PSSymantecSEPM { return $true }
            }

            It 'picks up memory-cached token through Initialize-SEPMSession' {
                $result = Initialize-SEPMSession
                $result | Should -BeOfType [PSCustomObject]
                $result.Headers.Authorization | Should -Be 'Bearer FakeTokenFromMemory'
                $result.TokenInfo | Should -Not -BeNullOrEmpty
                $result.TokenInfo | Should -Be $script:accessToken
            }
        }

        Context 'token cached on disk — via Initialize-SEPMSession' {
            BeforeAll {
                # Clear memory caches to force fallback to disk
                $script:accessToken = $null
                $script:_session   = $null

                # Write token file to disk
                $script:accessTokenFilePath = Join-Path -Path 'TestDrive:' -ChildPath 'token.xml'
                [PSCustomObject]@{
                    'token'              = 'FakeTokenFromDisk'
                    tokenExpiration      = (Get-Date).AddSeconds(3600)
                    SkipCertificateCheck = $true
                } | Export-Clixml -Path $script:accessTokenFilePath -Force

                Mock Test-SEPMAccessToken -ModuleName PSSymantecSEPM { return $true }
            }

            It 'reads disk-cached token through Initialize-SEPMSession' {
                $result = Initialize-SEPMSession
                $result | Should -BeOfType [PSCustomObject]
                $result.Headers.Authorization | Should -Be 'Bearer FakeTokenFromDisk'
                $result.TokenInfo | Should -Not -BeNullOrEmpty
                $result.TokenInfo.token | Should -Be 'FakeTokenFromDisk'
            }

            It 'promotes disk token to script:accessToken after session init' {
                $null = Initialize-SEPMSession
                $script:accessToken | Should -Not -BeNullOrEmpty
                $script:accessToken.token | Should -Be 'FakeTokenFromDisk'
            }
        }
    }
}
