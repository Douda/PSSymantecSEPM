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
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests/DummyDataGenerator.ps1')

            # Testing with a self-signed certificate
            # $URI = "https://FakeServer01:1234/console/apps/sepm"
            # $URI = "https://172.26.110.37:8443/console/apps/sepm"


        }

        AfterAll {
            # This is common test code teardown logic for all Pester test files
            $moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests\Config\Common-AfterAll.ps1')
        }

        Context 'Self-signed certificate exception' {
            BeforeAll {
                # Create a custom exception to throw certificate error
                $exception = New-Object System.Exception "Custom error message"
                $exception | Add-Member -MemberType NoteProperty -Name HttpRequestError -Value "SecureConnectionError"
                $exception | Add-Member -MemberType NoteProperty -Name Message -Value "The SSL connection could not be established, see inner exception." -Force
                $exception | Add-Member -MemberType NoteProperty -Name Source -Value "System.Net.Http" -Force
                $exception | Add-Member -MemberType NoteProperty -Name FullyQualifiedErrorId -Value "WebCmdletWebResponseException,Microsoft.PowerShell.Commands.InvokeWebRequestCommand" -Force


                # Create an ErrorRecord with the custom exception
                $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, "ErrorId", "NotSpecified", $null

                # Mock Invoke-WebRequest
                Mock Invoke-WebRequest -MockWith { throw $errorRecord }
            }
            
            # TODO: see if there is a better way to test the warning message
            It 'Should catch an error' {
                Mock -CommandName Write-Warning -ModuleName $script:moduleName
                Test-SEPMCertificate -URI "https://FakeServer01:1234/console/apps/sepm"
                Assert-MockCalled -CommandName Write-Warning -Exactly 1 -Scope It
            }
            
            It 'Should skip certificate check' {
                Test-SEPMCertificate -URI "https://FakeServer01:1234/console/apps/sepm"
                $script:SkipCert | Should -Be $true
            }
        }

        Context 'Valid certificate' {
            BeforeAll {
                # Mock Invoke-WebRequest
                Mock Invoke-WebRequest -MockWith { return $null }
            }
            
            It 'Should not throw' {
                { Test-SEPMCertificate -URI "https://FakeServer01:1234/console/apps/sepm" } | Should -Not -Throw
                $script:SkipCert | Should -Be $false
            }
        }
    }
}

