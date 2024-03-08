[CmdletBinding()]
param()

# Build & Load the module
$moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
. (Join-Path -Path $moduleRootPath -ChildPath 'Tests\Config\Common-Init.ps1')

Describe 'Initialize-PolicyExceptionStructure' {
    InModuleScope PSSymantecSEPM { 
        BeforeAll {
            # This is common test code setup logic for all Pester test files
            $moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests\Config\Common-BeforeAll.ps1')

            # Load Pester test environment setup
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests\Config\Common-TestEnvironmentSetup.ps1')

            # Load the dummy data generator functions
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests/DummyDataGenerator.ps1')

            # Mock Get-SEPMPoliciesSummary to return dummy data
            Mock Get-SEPMPoliciesSummary { 
                return New-DummyDataSEPMPoliciesSummary -PoliciesPerPolicyType 3
            }
        }

        AfterAll {
            # This is common test code teardown logic for all Pester test files
            $moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests\Config\Common-AfterAll.ps1')
        }

        # Investigate why the test fails
        It 'Returns correct object type' {
            $result = Initialize-PolicyExceptionStructure -PolicyName "policy fw 1"
            $result.ObjBody.PSobject.TypeNames[0] | Should -Be "SEPMPolicyExceptionsStructure"
            $result.ObjBody.name | Should -Be "policy fw 1"
            $result.PolicyID | Should -Not -BeNullOrEmpty
        } 
        
    }
}