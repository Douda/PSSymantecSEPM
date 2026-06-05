[CmdletBinding()]
param()

# Build & Load the module
$moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
. (Join-Path -Path $moduleRootPath -ChildPath 'Tests\Config\Common-Init.ps1')

Describe 'Clear-SEPMAuthentication' {
    InModuleScope PSSymantecSEPM { 
        BeforeAll {
            # This is common test code setup logic for all Pester test files
            $moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests\Config\Common-BeforeAll.ps1')

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

