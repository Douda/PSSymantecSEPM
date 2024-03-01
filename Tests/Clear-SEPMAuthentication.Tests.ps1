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
        }

        AfterAll {
            # This is common test code teardown logic for all Pester test files
            $moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests\Config\Common-AfterAll.ps1')
        }

        It 'Should remove credential and access token from memory' {
            Clear-SEPMAuthentication
            $script:Credential | Should -BeNullOrEmpty
            $script:accessToken | Should -BeNullOrEmpty
        }
    
        It 'Should remove credential and access token from file storage' {
            Clear-SEPMAuthentication
            $script:accessTokenFilePath | Should -Not -Exist
            $script:credentialsFilePath | Should -Not -Exist
        }
    }
}

