[CmdletBinding()]
param()

# Build & Load the module
$moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
. (Join-Path -Path $moduleRootPath -ChildPath 'Tests\Common-Init.ps1')


Describe 'Initialize-SepmConfiguration' {
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

        Context 'Configuration files' {
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

            Context 'Config file' {
                Context 'Configuration file contains no data' {
                    BeforeAll {
                        # Mock Import-SepmConfiguration
                        Mock Import-SepmConfiguration -ModuleName $script:moduleName { 
                            return [PSCustomObject]@{
                                'ServerAddress' = ''
                                'port'          = '8446'
                                'domain'        = ''
                            }
                        }

                        # Mock Reset-SEPMConfiguration
                        Mock Reset-SEPMConfiguration -ModuleName $script:moduleName {}
                    }

                    It 'Should call Reset-SEPMConfiguration' {
                        # Call the function
                        Initialize-SepmConfiguration

                        # Assert that Reset-SEPMConfiguration was called exactly once
                        Assert-MockCalled Reset-SEPMConfiguration -ModuleName $script:moduleName -Times 1 -Exactly
                    }
                }

                Context 'When the configuration file exist' {
                    BeforeAll {
                        # Mock Import-SepmConfiguration
                        Mock Import-SepmConfiguration -ModuleName $script:moduleName { 
                            return [PSCustomObject]@{
                                'ServerAddress' = 'FakeServer01'
                                'port'          = '1234'
                                'domain'        = ''
                            }
                        }
                    }

                    It 'Test configuration object values' {
                        # Call the function
                        Initialize-SepmConfiguration
    
                        $script:configuration | Should -Not -BeNullOrEmpty
                        $script:configuration.ServerAddress | Should -Be 'FakeServer01'
                        $script:configuration.port | Should -Be '1234'
                        $script:configuration.domain | Should -Be ''
                    }

                    It 'Test BaseURL' {
                        # Call the function
                        Initialize-SepmConfiguration
    
                        $script:BaseURLv1 | Should -Be 'https://FakeServer01:1234/sepm/api/v1'
                        $script:BaseURLv2 | Should -Be 'https://FakeServer01:1234/sepm/api/v2'
                    }
                }
            }

            Context 'Credential file' {
                Context 'Credential file exist' {
                    BeforeAll {
                        Mock Import-Clixml -ModuleName $script:moduleName -ParameterFilter { $Path -eq $script:credentialsFilePath } { return $creds }
                    }

                    It 'Should be PSCredential object' {
                        # Call the function
                        Initialize-SepmConfiguration

                        $script:Credential | Should -BeOfType [System.Management.Automation.PSCredential]
                        $script:Credential.UserName | Should -Be 'FakeUser'
                        $script:Credential.GetNetworkCredential().Password | Should -Be 'FakePassword'
                    }
                }
            }
            Context 'Token file' {
                Context 'Token file exist' {
                    BeforeAll {
                        Mock Import-Clixml -ModuleName $script:moduleName -ParameterFilter { $Path -eq $script:accessTokenFilePath } { 
                            return [PSCustomObject]@{
                                'token'              = 'FakeToken'
                                tokenExpiration      = (Get-Date).AddSeconds(3600)
                                SkipCertificateCheck = $true
                            }
                        }
                    }

                    It 'Should be PSCustomObject' {
                        # Call the function
                        Initialize-SepmConfiguration

                        $script:accessToken | Should -BeOfType [PSCustomObject]
                        $script:accessToken.token | Should -Be 'FakeToken'
                        $script:accessToken.tokenExpiration | Should -BeOfType [DateTime]
                        $script:accessToken.SkipCertificateCheck | Should -BeOfType [Boolean]
                    }
                }
            }
        }
    }
}