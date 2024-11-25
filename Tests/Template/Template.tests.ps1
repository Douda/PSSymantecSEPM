[CmdletBinding()]
param()

# Build & Load the module
$moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
. (Join-Path -Path $moduleRootPath -ChildPath 'Tests\Config\Common-Init.ps1')

# For Public function
Describe 'MyCommand' {
    BeforeAll {
        # This is common test code setup logic for all Pester test files
        $moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
        . (Join-Path -Path $moduleRootPath -ChildPath 'Tests\Config\Common-BeforeAll.ps1')

        # Load Pester test environment setup
        . (Join-Path -Path $moduleRootPath -ChildPath 'Tests\Config\Common-TestEnvironmentSetup.ps1')

        # Any mock ?
        # Mock Test-SEPMAccessToken -ModuleName $script:moduleName { return $true } 
    }

    AfterAll {
        # This is common test code teardown logic for all Pester test files
        $moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
        . (Join-Path -Path $moduleRootPath -ChildPath 'Tests\Config\Common-AfterAll.ps1')
    }

    Context 'token provided as parameter' {
        BeforeAll {}

        It 'Test 1' {
            $result = MyFunction
            $result | Should -Be "MyResult"
        }
        
        It 'Test 2' {}
    }
}

# For Private function (use InModuleScope to test private function)
Describe 'MyCommand' {
    InModuleScope PSSymantecSEPM { 
        BeforeAll {
            # This is common test code setup logic for all Pester test files
            $moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests\Config\Common-BeforeAll.ps1')

            # Load Pester test environment setup
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests\Config\Common-TestEnvironmentSetup.ps1')

            # Any mock ?
            # Mock Test-SEPMAccessToken -ModuleName $script:moduleName { return $true } 
        }

        AfterAll {
            # This is common test code teardown logic for all Pester test files
            $moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests\Config\Common-AfterAll.ps1')
        }

        Context 'token provided as parameter' {
            BeforeAll {}

            It 'Test 1' {
                $result = MyFunction
                $result | Should -Be "MyResult"
            }

            It 'Test 2' {}
        }
    }
}