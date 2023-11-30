[CmdletBinding()]
param()

# Build & Load the module
$moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
. (Join-Path -Path $moduleRootPath -ChildPath 'Tests\Common-Init.ps1')

Describe 'Get-SEPMAccessToken' {
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

    InModuleScope 'PSSymantecSEPM' {
        Context 'When token provided as parameter' {
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

        Context 'When token cached in memory' {
            BeforeAll {
                Mock Test-SEPMAccessToken -ModuleName $script:moduleName { return $true }
                $script:accessToken = [PSCustomObject]@{
                    'token'              = 'FakeToken'
                    tokenExpiration      = (Get-Date).AddSeconds(3600)
                    SkipCertificateCheck = $true
                }
            }

            It 'Test Token in memory' {
                $result = Get-SEPMAccessToken
                $result | Should -Be $script:accessToken
            }
        }

        Context 'When token cached in disk' {
            BeforeAll {
                # No token in memory
                $script:accessToken = $null

                Mock Test-SEPMAccessToken -ModuleName $script:moduleName { return $true }
                Mock Import-Clixml -ModuleName $script:moduleName -ParameterFilter { $Path -eq $script:accessTokenFilePath } { return [PSCustomObject]@{
                        'token'              = 'FakeToken'
                        tokenExpiration      = (Get-Date).AddSeconds(3600)
                        SkipCertificateCheck = $true
                    } }
                # Mock existing accessToken file
                Mock Test-Path -ModuleName $script:moduleName -ParameterFilter { $Path -eq $script:accessTokenFilePath } { return $true }
            }

            It 'Import file if it exists' {
                # Assert that Import-Clixml was called exactly once
                Assert-MockCalled Import-Clixml -ModuleName $script:moduleName -Times 2 -Exactly
            }

            It 'Test Token in disk' {
                $result = Get-SEPMAccessToken
                $result | Should -Be $script:accessToken
            }
        }

        Context 'When query token from SEPM' {
            Context 'When SEPM server name not configured' {
                BeforeAll {
                    $script:configuration.ServerAddress = $null
                }

                It 'Test SEPM server name not configured' {
                    $result = Get-SEPMAccessToken
                    $result | Should -Be $script:accessToken
                }
            }
        }
    }
}