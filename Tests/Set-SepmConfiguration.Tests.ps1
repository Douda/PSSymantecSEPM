[CmdletBinding()]
param()

Describe 'Set-SepmConfiguration' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Setting configuration from scratch' {
        It 'Creates config file and writes ServerAddress' {
            Set-SepmConfiguration -ServerAddress 'my-sepm.example.com'

            InModuleScope PSSymantecSEPM {
                Test-Path -Path $script:configurationFilePath -PathType Leaf | Should -Be $true
            }

            $content = InModuleScope PSSymantecSEPM {
                Get-Content -Path $script:configurationFilePath -Raw | ConvertFrom-Json
            }
            $content.ServerAddress | Should -Be 'my-sepm.example.com'
        }

        It 'Sets both ServerAddress and Port and verifies with Read-SepmConfiguration' {
            Set-SepmConfiguration -ServerAddress 'prod-sepm' -Port 9443

            InModuleScope PSSymantecSEPM {
                $persisted = Read-SepmConfiguration -Path $script:configurationFilePath
                $persisted.ServerAddress | Should -Be 'prod-sepm'
                $persisted.port | Should -Match '9443'
            }
        }
    }

    Context 'Updating existing configuration' {
        BeforeAll {
            Set-SepmConfiguration -ServerAddress 'original' -Port 8080
        }

        It 'Updates ServerAddress without changing Port' {
            Set-SepmConfiguration -ServerAddress 'updated'

            InModuleScope PSSymantecSEPM {
                $config = Get-Content -Path $script:configurationFilePath -Raw | ConvertFrom-Json
                $config.ServerAddress | Should -Be 'updated'
                $config.port | Should -Match '8080'
            }
        }

        It 'Updates Port without changing ServerAddress' {
            Set-SepmConfiguration -Port 9090

            InModuleScope PSSymantecSEPM {
                $config = Get-Content -Path $script:configurationFilePath -Raw | ConvertFrom-Json
                $config.ServerAddress | Should -Be 'updated'
                $config.port | Should -Match '9090'
            }
        }

        It 'Updates module-scope configuration after setting' {
            Set-SepmConfiguration -ServerAddress 'module-scope-test'

            InModuleScope PSSymantecSEPM {
                $script:configuration.ServerAddress | Should -Be 'module-scope-test'
            }
        }
    }

    Context 'Setting partial configuration' {
        BeforeAll {
            # Set a baseline with ServerAddress so Initialize-SepmConfiguration
            # doesn't reset the config when we only set Port
            Set-SepmConfiguration -ServerAddress 'partial-baseline' -Port 8080
        }

        It 'Updates only Port while keeping existing ServerAddress' {
            Set-SepmConfiguration -Port 7000

            InModuleScope PSSymantecSEPM {
                $config = Read-SepmConfiguration -Path $script:configurationFilePath
                $config.port | Should -Match '7000'
            }

            InModuleScope PSSymantecSEPM {
                $script:configuration.ServerAddress | Should -Be 'partial-baseline'
            }
        }
    }
}
