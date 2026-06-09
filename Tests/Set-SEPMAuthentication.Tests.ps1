[CmdletBinding()]
param()

Describe 'Set-SEPMAuthentication' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    It 'saves credential to disk' {
        $credsPath = Join-Path -Path 'TestDrive:' -ChildPath 'creds.xml'
        $dummyCreds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'FakeDummyUser',
            (ConvertTo-SecureString -String 'FakeDummyPassword' -AsPlainText -Force)

        Set-SEPMAuthentication -Credentials $dummyCreds

        $savedCreds = Import-Clixml -Path $credsPath
        $savedCreds | Should -BeOfType [System.Management.Automation.PSCredential]
        $savedCreds.UserName | Should -Be 'FakeDummyUser'
    }

    It 'overwrites previously saved credential on disk' {
        $credsPath = Join-Path -Path 'TestDrive:' -ChildPath 'creds.xml'

        $creds1 = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'UserOne',
            (ConvertTo-SecureString -String 'PassOne' -AsPlainText -Force)
        Set-SEPMAuthentication -Credentials $creds1

        $creds2 = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'UserTwo',
            (ConvertTo-SecureString -String 'PassTwo' -AsPlainText -Force)
        Set-SEPMAuthentication -Credentials $creds2

        $savedCreds = Import-Clixml -Path $credsPath
        $savedCreds.UserName | Should -Be 'UserTwo'
    }
}
