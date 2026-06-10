[CmdletBinding()]
param()

Describe 'Backup-SEPMAuthentication' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
        $script:CredsPath = Join-Path -Path 'TestDrive:' -ChildPath 'creds.xml'
        $script:TokenPath = Join-Path -Path 'TestDrive:' -ChildPath 'token.xml'
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Credential backup' {
        BeforeAll {
            # Write fixture credential directly to TestDrive — Initialize-TestEnvironment
            # already redirected $script:credentialsFilePath to this path.
            $dummyCreds = New-Object System.Management.Automation.PSCredential 'TestUser',
                (ConvertTo-SecureString -String 'TestPass' -AsPlainText -Force)
            $parent = Split-Path -Path $script:CredsPath -Parent
            $null = New-Item -Path $parent -ItemType Directory -Force -ErrorAction SilentlyContinue
            $dummyCreds | Export-Clixml -Path $script:CredsPath
        }

        It 'Backs up credentials file when -Credential is used' {
            $backupPath = Join-Path -Path 'TestDrive:' -ChildPath 'backups/cred-backup.xml'
            $null = Backup-SEPMAuthentication -Path $backupPath -Credentials

            Test-Path -Path $backupPath -PathType Leaf | Should -Be $true
        }

        It 'Backed up file contains correct credentials' {
            $backupPath = Join-Path -Path 'TestDrive:' -ChildPath 'backups/cred-verify.xml'
            $null = Backup-SEPMAuthentication -Path $backupPath -Credentials

            $restored = Import-Clixml -Path $backupPath
            $restored.UserName | Should -Be 'TestUser'
        }

        It 'Does not create backup when credentials file doesnt exist' {
            $emptyBackupPath = Join-Path -Path 'TestDrive:' -ChildPath 'backups/no-cred-backup.xml'

            if (Test-Path -Path $script:CredsPath) {
                Remove-Item -Path $script:CredsPath -Force
            }

            $null = Backup-SEPMAuthentication -Path $emptyBackupPath -Credentials
            Test-Path -Path $emptyBackupPath -PathType Leaf | Should -Be $false
        }
    }

    Context 'AccessToken backup' {
        BeforeAll {
            # Write fixture token directly to TestDrive — Initialize-TestEnvironment
            # already redirected $script:accessTokenFilePath to this path.
            $parent = Split-Path -Path $script:TokenPath -Parent
            $null = New-Item -Path $parent -ItemType Directory -Force -ErrorAction SilentlyContinue
            $fakeToken = [PSCustomObject]@{
                Token           = 'fake-token-value'
                TokenExpiration = (Get-Date).AddHours(1)
            }
            $fakeToken | Export-Clixml -Path $script:TokenPath
        }

        It 'Backs up access token file when -AccessToken is used' {
            $backupPath = Join-Path -Path 'TestDrive:' -ChildPath 'backups/token-backup.xml'
            $null = Backup-SEPMAuthentication -Path $backupPath -AccessToken

            Test-Path -Path $backupPath -PathType Leaf | Should -Be $true
        }

        It 'Backed up file contains valid token data' {
            $backupPath = Join-Path -Path 'TestDrive:' -ChildPath 'backups/token-verify.xml'
            $null = Backup-SEPMAuthentication -Path $backupPath -AccessToken

            $restored = Import-Clixml -Path $backupPath
            $restored.Token | Should -Be 'fake-token-value'
        }
    }

    Context 'Backup with both credential and token files present' {
        BeforeAll {
            $parent = Split-Path -Path $script:CredsPath -Parent
            $null = New-Item -Path $parent -ItemType Directory -Force -ErrorAction SilentlyContinue

            $dummyCreds = New-Object System.Management.Automation.PSCredential 'BothUser',
                (ConvertTo-SecureString -String 'BothPass' -AsPlainText -Force)
            $dummyCreds | Export-Clixml -Path $script:CredsPath

            $fakeToken = [PSCustomObject]@{ Token = 'both-token'; TokenExpiration = (Get-Date).AddHours(2) }
            $fakeToken | Export-Clixml -Path $script:TokenPath
        }

        It 'Backs up both files when both switches are used' {
            $credBackup = Join-Path -Path 'TestDrive:' -ChildPath 'backups/both-cred.xml'
            $tokenBackup = Join-Path -Path 'TestDrive:' -ChildPath 'backups/both-token.xml'

            $null = Backup-SEPMAuthentication -Path $credBackup -Credentials
            $null = Backup-SEPMAuthentication -Path $tokenBackup -AccessToken

            Test-Path -Path $credBackup -PathType Leaf | Should -Be $true
            Test-Path -Path $tokenBackup -PathType Leaf | Should -Be $true
        }
    }
}
