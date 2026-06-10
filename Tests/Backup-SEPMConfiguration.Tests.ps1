[CmdletBinding()]
param()

Describe 'Backup-SEPMConfiguration' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
        $script:ConfigPath = Join-Path -Path 'TestDrive:' -ChildPath 'config.json'
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'With existing configuration' {
        BeforeAll {
            Set-SepmConfiguration -ServerAddress 'testserver' -Port 8446
        }

        It 'Creates a backup file at the specified path' {
            $backupPath = Join-Path -Path 'TestDrive:' -ChildPath 'backups/config-backup.json'
            $null = Backup-SEPMConfiguration -Path $backupPath

            Test-Path -Path $backupPath -PathType Leaf | Should -Be $true
        }

        It 'Backup file contains the config content' {
            $backupPath = Join-Path -Path 'TestDrive:' -ChildPath 'backups/config-content.json'
            $null = Backup-SEPMConfiguration -Path $backupPath

            $content = Get-Content -Path $backupPath -Raw | ConvertFrom-Json
            $content.ServerAddress | Should -Be 'testserver'
            $content.port | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Without existing configuration' {
        BeforeAll {
            # Remove config file directly from TestDrive — Initialize-TestEnvironment
            # already redirected $script:configurationFilePath to this path.
            if (Test-Path -Path $script:ConfigPath -PathType Leaf) {
                Remove-Item -Path $script:ConfigPath -Force
            }
        }

        It 'Backs up an empty JSON object when no config exists' {
            $backupPath = Join-Path -Path 'TestDrive:' -ChildPath 'backups/empty-config.json'
            $null = Backup-SEPMConfiguration -Path $backupPath

            Test-Path -Path $backupPath -PathType Leaf | Should -Be $true
            $content = Get-Content -Path $backupPath -Raw
            # Empty config produces empty JSON object (normalize line endings for PS 5.1)
            $content.Trim() -replace '\s' | Should -Be '{}'
        }
    }

    Context 'Force parameter' {
        BeforeAll {
            Set-SepmConfiguration -ServerAddress 'force-test' -Port 8446
        }

        It 'Overwrites existing backup file when Force is specified' {
            $backupPath = Join-Path -Path 'TestDrive:' -ChildPath 'backups/force-backup.json'

            # Create a pre-existing file
            $null = New-Item -Path $backupPath -ItemType File -Force -Value 'old-content'

            $null = Backup-SEPMConfiguration -Path $backupPath -Force

            $content = Get-Content -Path $backupPath -Raw | ConvertFrom-Json
            $content.ServerAddress | Should -Be 'force-test'
        }
    }

    Context 'Path acceptance' {
        BeforeAll {
            Set-SepmConfiguration -ServerAddress 'path-accept-test' -Port 8446
        }

        It 'Accepts Path parameter and creates backup' {
            $backupPath = Join-Path -Path 'TestDrive:' -ChildPath 'backups/path-backup.json'
            $null = Backup-SEPMConfiguration -Path $backupPath

            Test-Path -Path $backupPath | Should -Be $true
        }
    }
}
