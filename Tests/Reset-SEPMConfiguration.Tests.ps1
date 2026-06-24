[CmdletBinding()]
param()

Describe 'Reset-SEPMConfiguration' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
        $script:ConfigPath = Join-Path -Path 'TestDrive:' -ChildPath 'config.json'
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Reset with existing configuration' {
        BeforeAll {
            Set-SEPMConfiguration -ServerAddress 'before-reset' -Port 8446
        }

        It 'Removes the configuration file from disk' {
            Reset-SEPMConfiguration

            Test-Path -Path $script:ConfigPath -PathType Leaf | Should -Be $false
        }
    }

    Context 'Reset when no configuration exists' {
        BeforeAll {
            if (Test-Path -Path $script:ConfigPath -PathType Leaf) {
                Remove-Item -Path $script:ConfigPath -Force
            }
        }

        It 'Does not throw when no configuration file exists' {
            { Reset-SEPMConfiguration } | Should -Not -Throw
        }
    }

    Context 'Configuration file is truly removed' {
        It 'Delete is effective after set and reset' {
            Set-SEPMConfiguration -ServerAddress 'ephemeral' -Port 8446

            # Verify file exists before reset
            Test-Path -Path $script:ConfigPath -PathType Leaf | Should -Be $true

            Reset-SEPMConfiguration

            # Verify file is gone after reset
            Test-Path -Path $script:ConfigPath -PathType Leaf | Should -Be $false
        }
    }
}
