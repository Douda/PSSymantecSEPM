[CmdletBinding()]
param()

# Build & Load the module
$moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
. (Join-Path -Path $moduleRootPath -ChildPath 'Tests\Config\Common-Init.ps1')

Describe 'Get-SEPComputers' {
    InModuleScope PSSymantecSEPM { 
        BeforeAll {
            # This is common test code setup logic for all Pester test files
            $moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests\Config\Common-BeforeAll.ps1')

            # Load Pester test environment setup
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests\Config\Common-TestEnvironmentSetup.ps1')

            # Load the dummy data generator functions
            # . (Join-Path -Path $moduleRootPath -ChildPath 'Tests/DummyDataGenerator.ps1')

            # Mock Get-Credential to return dummy credentials
            Mock Get-Credential { 
                $creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'FakeDummyUser', 
                    (ConvertTo-SecureString -String 'FakeDummyPassword' -AsPlainText -Force)
                return $creds
            }
            
        }

        AfterAll {
            # This is common test code teardown logic for all Pester test files
            $moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests\Config\Common-AfterAll.ps1')
        }

        It 'Should have credential loaded in memory' {
            Set-SEPMAuthentication -Credentials (Get-Credential)
            $script:Credential | Should -Not -BeNullOrEmpty
            $script:Credential.UserName | Should -Be 'FakeDummyUser'
            $script:Credential | Should -BeOfType [System.Management.Automation.PSCredential]
        }

        It 'Should have credential saved to disk' {
            Set-SEPMAuthentication -Credentials (Get-Credential)
            $TestCreds = Import-Clixml -Path $script:credentialsFilePath
            $TestCreds | Should -BeOfType [System.Management.Automation.PSCredential]
            $TestCreds.UserName | Should -Be 'FakeDummyUser'
        }
    }
}

