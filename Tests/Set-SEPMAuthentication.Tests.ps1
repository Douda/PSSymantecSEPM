[CmdletBinding()]
param()

# Build & Load the module
$moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
. (Join-Path -Path $moduleRootPath -ChildPath 'Tests/Config/Common-Init.ps1')

Describe 'Get-SEPComputers' {
    InModuleScope PSSymantecSEPM { 
        BeforeAll {
            # This is common test code setup logic for all Pester test files
            $moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests/Config/Common-BeforeAll.ps1')

            # Override file paths to isolate from real config
            $script:configurationFilePath = Join-Path -Path 'TestDrive:' -ChildPath 'config.json'
            $script:credentialsFilePath  = Join-Path -Path 'TestDrive:' -ChildPath 'creds.xml'
            $script:accessTokenFilePath  = Join-Path -Path 'TestDrive:' -ChildPath 'token.xml'
        }

        AfterAll {
            # This is common test code teardown logic for all Pester test files
            $moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests/Config/Common-AfterAll.ps1')
        }

        It 'Should have credential loaded in memory' {
            $dummyCreds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'FakeDummyUser',
                (ConvertTo-SecureString -String 'FakeDummyPassword' -AsPlainText -Force)
            Set-SEPMAuthentication -Credentials $dummyCreds
            $script:Credential | Should -Not -BeNullOrEmpty
            $script:Credential.UserName | Should -Be 'FakeDummyUser'
            $script:Credential | Should -BeOfType [System.Management.Automation.PSCredential]
        }

        It 'Should have credential saved to disk' {
            $dummyCreds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'FakeDummyUser',
                (ConvertTo-SecureString -String 'FakeDummyPassword' -AsPlainText -Force)
            Set-SEPMAuthentication -Credentials $dummyCreds
            $TestCreds = Import-Clixml -Path $script:credentialsFilePath
            $TestCreds | Should -BeOfType [System.Management.Automation.PSCredential]
            $TestCreds.UserName | Should -Be 'FakeDummyUser'
        }
    }
}
