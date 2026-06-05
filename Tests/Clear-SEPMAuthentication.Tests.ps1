[CmdletBinding()]
param()

Describe 'Clear-SEPMAuthentication' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment

        InModuleScope PSSymantecSEPM {
            # Override file paths to isolate from real config
            $script:configurationFilePath = Join-Path -Path 'TestDrive:' -ChildPath 'config.json'
            $script:credentialsFilePath  = Join-Path -Path 'TestDrive:' -ChildPath 'creds.xml'
            $script:accessTokenFilePath  = Join-Path -Path 'TestDrive:' -ChildPath 'token.xml'

            # Stage credentials and token for Clear tests
            $creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'FakeUser', (ConvertTo-SecureString -String 'FakePassword' -AsPlainText -Force)
            $creds | Export-Clixml -Path $script:credentialsFilePath -Force
            $script:Credential = $creds

            $script:accessToken = [PSCustomObject]@{ token = 'FakeToken'; tokenExpiration = (Get-Date).AddHours(1) }
            $script:accessToken | Export-Clixml -Path $script:accessTokenFilePath -Force
        }
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    It 'Should remove credential and access token from memory' {
        InModuleScope PSSymantecSEPM {
            Clear-SEPMAuthentication
            $script:Credential | Should -BeNullOrEmpty
            $script:accessToken | Should -BeNullOrEmpty
        }
    }

    It 'Should remove credential and access token from file storage' {
        InModuleScope PSSymantecSEPM {
            Clear-SEPMAuthentication
            $script:accessTokenFilePath | Should -Not -Exist
            $script:credentialsFilePath | Should -Not -Exist
        }
    }
}
