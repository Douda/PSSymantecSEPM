[CmdletBinding()]
param()

Describe 'Set-SEPMConfiguration' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
        $script:ConfigPath = Join-Path -Path 'TestDrive:' -ChildPath 'config.json'
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Setting configuration from scratch' {
        It 'Creates config file and writes ServerAddress' {
            Set-SEPMConfiguration -ServerAddress 'my-sepm.example.com'

            Test-Path -Path $script:ConfigPath -PathType Leaf | Should -Be $true

            $content = Get-Content -Path $script:ConfigPath -Raw | ConvertFrom-Json
            $content.ServerAddress | Should -Be 'my-sepm.example.com'
        }

        It 'Sets both ServerAddress and Port and persists to disk' {
            Set-SEPMConfiguration -ServerAddress 'prod-sepm' -Port 9443

            $persisted = Get-Content -Path $script:ConfigPath -Raw | ConvertFrom-Json
            $persisted.ServerAddress | Should -Be 'prod-sepm'
            $persisted.port | Should -Match '9443'
        }
    }

    Context 'Updating existing configuration' {
        BeforeAll {
            Set-SEPMConfiguration -ServerAddress 'original' -Port 8080
        }

        It 'Updates ServerAddress without changing Port' {
            Set-SEPMConfiguration -ServerAddress 'updated'

            $config = Get-Content -Path $script:ConfigPath -Raw | ConvertFrom-Json
            $config.ServerAddress | Should -Be 'updated'
            $config.port | Should -Match '8080'
        }

        It 'Updates Port without changing ServerAddress' {
            Set-SEPMConfiguration -Port 9090

            $config = Get-Content -Path $script:ConfigPath -Raw | ConvertFrom-Json
            $config.ServerAddress | Should -Be 'updated'
            $config.port | Should -Match '9090'
        }

        It 'Persists new ServerAddress to disk' {
            Set-SEPMConfiguration -ServerAddress 'module-scope-test'

            $config = Get-Content -Path $script:ConfigPath -Raw | ConvertFrom-Json
            $config.ServerAddress | Should -Be 'module-scope-test'
        }
    }

    Context 'Setting partial configuration' {
        BeforeAll {
            # Set a baseline with ServerAddress so Initialize-SepmConfiguration
            # doesn't reset the config when we only set Port
            Set-SEPMConfiguration -ServerAddress 'partial-baseline' -Port 8080
        }

        It 'Updates only Port while keeping existing ServerAddress' {
            Set-SEPMConfiguration -Port 7000

            $config = Get-Content -Path $script:ConfigPath -Raw | ConvertFrom-Json
            $config.port | Should -Match '7000'
            $config.ServerAddress | Should -Be 'partial-baseline'
        }
    }
}
