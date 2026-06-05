[CmdletBinding()]
param()

Describe 'Set-SEPMAuthentication' {
    BeforeAll {
        # Import TestHelpers and initialize the test environment
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment

        # Override file paths to isolate from real config
        InModuleScope PSSymantecSEPM {
            $script:configurationFilePath = Join-Path -Path 'TestDrive:' -ChildPath 'config.json'
            $script:credentialsFilePath   = Join-Path -Path 'TestDrive:' -ChildPath 'creds.xml'
            $script:accessTokenFilePath   = Join-Path -Path 'TestDrive:' -ChildPath 'token.xml'
        }
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    It 'Should have credential loaded in memory' {
        InModuleScope PSSymantecSEPM {
            $dummyCreds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'FakeDummyUser',
                (ConvertTo-SecureString -String 'FakeDummyPassword' -AsPlainText -Force)
            Set-SEPMAuthentication -Credentials $dummyCreds
            $script:Credential | Should -Not -BeNullOrEmpty
            $script:Credential.UserName | Should -Be 'FakeDummyUser'
            $script:Credential | Should -BeOfType [System.Management.Automation.PSCredential]
        }
    }

    It 'Should have credential saved to disk' {
        InModuleScope PSSymantecSEPM {
            $dummyCreds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'FakeDummyUser',
                (ConvertTo-SecureString -String 'FakeDummyPassword' -AsPlainText -Force)
            Set-SEPMAuthentication -Credentials $dummyCreds
            $TestCreds = Import-Clixml -Path $script:credentialsFilePath
            $TestCreds | Should -BeOfType [System.Management.Automation.PSCredential]
            $TestCreds.UserName | Should -Be 'FakeDummyUser'
        }
    }
}
