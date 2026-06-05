[CmdletBinding()]
param()

# Build & Load the module
$moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
. (Join-Path -Path $moduleRootPath -ChildPath 'Tests\Config\Common-Init.ps1')

# Test git update

Describe 'Build-SEPMQueryURI' {
    InModuleScope PSSymantecSEPM { 
        BeforeAll {
            # This is common test code setup logic for all Pester test files
            $moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests\Config\Common-BeforeAll.ps1')

            # Build-SEPMQueryURI is a pure function; no module state needed
        }

        AfterAll {
            # This is common test code teardown logic for all Pester test files
            $moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests\Config\Common-AfterAll.ps1')
        }

        It 'Single URI parameter' {
            $baseUrl = 'https://FakeServer01:1234/sepm/api/v1'
            $URI = $baseUrl + '/computers'
            $QueryStrings = @{
                computerName = "TestComputer01"
            }
            $result = Build-SEPMQueryURI -BaseURI $URI -QueryStrings $QueryStrings
            $result | Should -Be ($URI + "?computerName=TestComputer01")
        }

        It 'Multiple URI parameters' {
            $baseUrl = 'https://FakeServer01:1234/sepm/api/v1'
            $URI = $baseUrl + '/computers'
            $QueryStrings = @{
                sort      = "COMPUTER_NAME"
                pageIndex = 1
                pageSize  = 100
            }
            $result = Build-SEPMQueryURI -BaseURI $URI -QueryStrings $QueryStrings
            $result | Should -Match "sort=COMPUTER_NAME"
            $result | Should -Match "pageIndex=1"
            $result | Should -Match "pageSize=100"
        }

        It 'Should return base URI when no query strings are provided' {
            $baseUrl = 'https://FakeServer01:1234/sepm/api/v1'
            $URI = $baseUrl + '/computers'
            $result = Build-SEPMQueryURI -BaseURI $URI -QueryStrings @{}
            $result | Should -Be $URI
        }
    }
}

