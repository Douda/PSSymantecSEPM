[CmdletBinding()]
param()

# Build & Load the module
$moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
. (Join-Path -Path $moduleRootPath -ChildPath 'Tests\Common-Init.ps1')

Describe 'Get-SEPComputers' {
    InModuleScope PSSymantecSEPM { 
        BeforeAll {
            # This is common test code setup logic for all Pester test files
            $moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests\Common-BeforeAll.ps1')
        }

        AfterAll {
            # This is common test code teardown logic for all Pester test files
            $moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests\Common-AfterAll.ps1')
        }

        Context 'Get-SEPComputers context' {
            BeforeAll {
                # Mock Test-SEPMAccessToken for valid token
                Mock Test-SEPMAccessToken -ModuleName $script:moduleName { return $true }
            }
        }
    }
}

