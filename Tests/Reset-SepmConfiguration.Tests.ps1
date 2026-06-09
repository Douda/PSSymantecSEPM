[CmdletBinding()]
param()

Describe 'Reset-SepmConfiguration' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Reset with existing configuration' {
        BeforeAll {
            Set-SepmConfiguration -ServerAddress 'before-reset' -Port 8446
        }

        It 'Removes the configuration file from disk' {
            Reset-SEPMConfiguration

            InModuleScope PSSymantecSEPM {
                Test-Path -Path $script:configurationFilePath -PathType Leaf | Should -Be $false
            }
        }
    }

    Context 'Reset when no configuration exists' {
        BeforeAll {
            InModuleScope PSSymantecSEPM {
                if (Test-Path -Path $script:configurationFilePath -PathType Leaf) {
                    Remove-Item -Path $script:configurationFilePath -Force
                }
            }
        }

        It 'Does not throw when no configuration file exists' {
            { Reset-SEPMConfiguration } | Should -Not -Throw
        }
    }

    Context 'Configuration file is truly removed' {
        It 'Delete is effective after set and reset' {
            Set-SepmConfiguration -ServerAddress 'ephemeral' -Port 8446

            # Verify file exists before reset
            $fileExistedBefore = InModuleScope PSSymantecSEPM {
                Test-Path -Path $script:configurationFilePath -PathType Leaf
            }
            $fileExistedBefore | Should -Be $true

            Reset-SEPMConfiguration

            # Verify file is gone after reset
            $fileExistsAfter = InModuleScope PSSymantecSEPM {
                Test-Path -Path $script:configurationFilePath -PathType Leaf
            }
            $fileExistsAfter | Should -Be $false
        }
    }
}
