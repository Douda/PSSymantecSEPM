[CmdletBinding()]
param()

Describe 'Restore-SEPMAuthentication' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
        $script:CredsPath = Join-Path -Path 'TestDrive:' -ChildPath 'creds.xml'
        $script:TokenPath = Join-Path -Path 'TestDrive:' -ChildPath 'token.xml'
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Credential restore' {
        It 'Copies source credential file to module credential path' {
            $sourcePath = Join-Path -Path 'TestDrive:' -ChildPath 'sources/my-creds.xml'
            $null = New-Item -Path (Split-Path -Path $sourcePath -Parent) -ItemType Directory -Force
            $creds = New-Object System.Management.Automation.PSCredential 'RestoredUser',
                (ConvertTo-SecureString -String 'RestoredPass' -AsPlainText -Force)
            $creds | Export-Clixml -Path $sourcePath

            Restore-SEPMAuthentication -Path $sourcePath -Credential

            Test-Path -Path $script:CredsPath -PathType Leaf | Should -Be $true
            $restored = Import-Clixml -Path $script:CredsPath
            $restored.UserName | Should -Be 'RestoredUser'
        }
    }

    Context 'AccessToken restore' {
        It 'Copies source token file to module token path' {
            $sourcePath = Join-Path -Path 'TestDrive:' -ChildPath 'sources/my-token.xml'
            $null = New-Item -Path (Split-Path -Path $sourcePath -Parent) -ItemType Directory -Force
            $token = [PSCustomObject]@{ Token = 'restored-token'; TokenExpiration = (Get-Date).AddHours(3) }
            $token | Export-Clixml -Path $sourcePath

            Restore-SEPMAuthentication -Path $sourcePath -AccessToken

            Test-Path -Path $script:TokenPath -PathType Leaf | Should -Be $true
            $restored = Import-Clixml -Path $script:TokenPath
            $restored.Token | Should -Be 'restored-token'
        }
    }

    Context 'Parameter validation' {
        It 'Throws for a non-existent file path' {
            $nonExistentPath = Join-Path -Path 'TestDrive:' -ChildPath 'sources/not-here.xml'

            { Restore-SEPMAuthentication -Path $nonExistentPath -Credential } |
                Should -Throw -ErrorId 'ParameterArgumentValidationError,Restore-SEPMAuthentication'
        }

        It 'Throws for non-existent file with AccessToken switch' {
            $nonExistentPath = Join-Path -Path 'TestDrive:' -ChildPath 'sources/missing.xml'

            { Restore-SEPMAuthentication -Path $nonExistentPath -AccessToken } |
                Should -Throw -ErrorId 'ParameterArgumentValidationError,Restore-SEPMAuthentication'
        }
    }

    Context 'Overwrite existing file' {
        It 'Overwrites existing credential file with restored file' {
            # Stage an old credential file directly on TestDrive
            $parent = Split-Path -Path $script:CredsPath -Parent
            $null = New-Item -Path $parent -ItemType Directory -Force -ErrorAction SilentlyContinue
            $oldCreds = New-Object System.Management.Automation.PSCredential 'OldUser',
                (ConvertTo-SecureString -String 'OldPass' -AsPlainText -Force)
            $oldCreds | Export-Clixml -Path $script:CredsPath

            $sourcePath = Join-Path -Path 'TestDrive:' -ChildPath 'sources/new-creds.xml'
            $null = New-Item -Path (Split-Path -Path $sourcePath -Parent) -ItemType Directory -Force
            $newCreds = New-Object System.Management.Automation.PSCredential 'NewUser',
                (ConvertTo-SecureString -String 'NewPass' -AsPlainText -Force)
            $newCreds | Export-Clixml -Path $sourcePath

            Restore-SEPMAuthentication -Path $sourcePath -Credential

            $restored = Import-Clixml -Path $script:CredsPath
            $restored.UserName | Should -Be 'NewUser'
        }
    }
}
