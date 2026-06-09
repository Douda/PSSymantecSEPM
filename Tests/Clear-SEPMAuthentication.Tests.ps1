[CmdletBinding()]
param()

Describe 'Clear-SEPMAuthentication' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    It 'removes credential file from disk when present' {
        $credsPath = Join-Path -Path 'TestDrive:' -ChildPath 'creds.xml'
        $dummyCreds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'FakeUser',
            (ConvertTo-SecureString -String 'FakePassword' -AsPlainText -Force)
        $dummyCreds | Export-Clixml -Path $credsPath -Force

        Clear-SEPMAuthentication

        $credsPath | Should -Not -Exist
    }

    It 'removes access token file from disk when present' {
        $tokenPath = Join-Path -Path 'TestDrive:' -ChildPath 'token.xml'
        $token = [PSCustomObject]@{ token = 'FakeToken'; tokenExpiration = (Get-Date).AddHours(1) }
        $token | Export-Clixml -Path $tokenPath -Force

        Clear-SEPMAuthentication

        $tokenPath | Should -Not -Exist
    }

    It 'does not throw when files do not exist (idempotent)' {
        { Clear-SEPMAuthentication } | Should -Not -Throw
    }

    It 'clears both credential and token files in one call' {
        $credsPath = Join-Path -Path 'TestDrive:' -ChildPath 'creds.xml'
        $tokenPath = Join-Path -Path 'TestDrive:' -ChildPath 'token.xml'

        $dummyCreds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'FakeUser',
            (ConvertTo-SecureString -String 'FakePassword' -AsPlainText -Force)
        $dummyCreds | Export-Clixml -Path $credsPath -Force

        $token = [PSCustomObject]@{ token = 'FakeToken'; tokenExpiration = (Get-Date).AddHours(1) }
        $token | Export-Clixml -Path $tokenPath -Force

        Clear-SEPMAuthentication

        $credsPath | Should -Not -Exist
        $tokenPath | Should -Not -Exist
    }
}
