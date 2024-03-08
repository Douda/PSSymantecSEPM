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

            # Mock Test-SEPMAccessToken to return true for valid token
            Mock Test-SEPMAccessToken -ModuleName $script:moduleName { return $true }

            # API Call - 1st page always contains 100 computers
            $script:APIResponseFirstPage = [PSCustomObject]@{
                content   = (1..100 | ForEach-Object { New-DummyDataSEPComputers })
                firstPage = $true
                lastPage  = $false
            }

            # API Call - Last page always contains 5 computers
            $script:APIResponseLastPage = [PSCustomObject]@{
                content   = (1..5 | ForEach-Object { New-DummyDataSEPComputers })
                firstPage = $false
                lastPage  = $true
            }

            # Mock Invoke-ABRestMethod to return a valid response with only one page / 5 computers
            Mock Invoke-ABRestMethod -ModuleName $script:moduleName -ParameterFilter {
                $params.Uri -eq $URI -and $params.Method -eq 'GET'
            } { 
                return $script:APIResponseLastPage
            }
        }

        AfterAll {
            # This is common test code teardown logic for all Pester test files
            $moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests\Config\Common-AfterAll.ps1')
        }

        Context 'No parameters' {
            BeforeAll {}

            It 'Should return exactly one page of computers' {
                $result = Get-SEPComputers
                $result | Should -Not -BeNullOrEmpty
                $result.count | Should -Be 5
                # Only one API call
                Should -Invoke Invoke-ABRestMethod -Exactly 1 -Scope It
            }

            It 'Should have the expected type' {
                $result = Get-SEPComputers
                $result[0].PSObject.TypeNames[0] | Should -Be 'SEP.Computer'
            }
            

            Context 'With pagination' {
                BeforeAll {
                    # Mock Invoke-ABRestMethod to return a valid response with multiple pages
                    $script:callCount = 0
                    Mock Invoke-ABRestMethod -ModuleName $script:moduleName -ParameterFilter {
                        $params.Uri -eq $URI -and $params.Method -eq 'GET'
                    } { 
                        $script:callCount++
                        if ($script:callCount -ge 2) {
                            return $script:APIResponseLastPage
                        } else {
                            return $script:APIResponseFirstPage
                        }
                    }
                }

                It 'Should perform exactly 2 API calls to get all computers' {
                    $result = Get-SEPComputers
                    $result | Should -Not -BeNullOrEmpty
                    # Exactly two API calls
                    Should -Invoke Invoke-ABRestMethod -Exactly 2 -Scope It
                }
            }
        }

        Context 'ComputerName parameter' {
            BeforeAll {
                # Mock Invoke-ABRestMethod to return a valid response with computers, including one called "MyComputer"
                Mock Invoke-ABRestMethod -ModuleName $script:moduleName -ParameterFilter {
                    $params.Uri -eq $URI -and $params.Method -eq 'GET'
                } { 
                    return [PSCustomObject]@{
                        content   = (, @(New-DummyDataSEPComputers -ComputerName "MyComputer")) + # Create an array with one computer
                                    (1..4 | ForEach-Object { New-DummyDataSEPComputers })
                        firstPage = $true
                        lastPage  = $true
                    }
                }
            }
            It 'Should contain MyComputer only' {
                $result = Get-SEPComputers -ComputerName "MyComputer"
                $result | Should -Not -BeNullOrEmpty
                $result.computername | Should -Be "MyComputer"
            }

            It 'With Computername from the pipeline' {
                $result = "MyComputer" | Get-SEPComputers
                $result | Should -Not -BeNullOrEmpty
                $result.computername | Should -Be "MyComputer"
            }

            It 'Should have the expected type' {
                $result = Get-SEPComputers -ComputerName "MyComputer"
                $result.PSObject.TypeNames[0] | Should -Be 'SEP.Computer'
            }
        }

        Context 'GroupName parameter' {
            BeforeAll {
                # Mock Invoke-ABRestMethod to return a valid response
                # 2 pages / 20+ computers / 2 specific groups
                $script:callCount = 0
                Mock Invoke-ABRestMethod -ModuleName $script:moduleName -ParameterFilter {
                    $params.Uri -eq $URI -and $params.Method -eq 'GET'
                } { 
                    $script:callCount++
                    if ($script:callCount -ge 2) {
                        return [PSCustomObject]@{
                            content   = (1..5 | ForEach-Object { New-DummyDataSEPComputers -GroupName "My Company\\MyGroup" }) + 
                                        (1..5 | ForEach-Object { New-DummyDataSEPComputers -GroupName "My Company\\MyGroup\\Subgroup" })
                            firstPage = $false
                            lastPage  = $true
                        }
                    } else {
                        return [PSCustomObject]@{
                            content   = (1..5 | ForEach-Object { New-DummyDataSEPComputers -GroupName "My Company\\MyGroup" }) + 
                                        (1..5 | ForEach-Object { New-DummyDataSEPComputers -GroupName "My Company\\MyGroup\\Subgroup" }) +
                                        (1..8 | ForEach-Object { New-DummyDataSEPComputers })
                            firstPage = $true
                            lastPage  = $false
                        }
                    }
                }
            }
            It 'Should contain only computers from the group "My Company\\MyGroup"' {
                $result = Get-SEPComputers -GroupName "My Company\\MyGroup"
                $result | Should -Not -BeNullOrEmpty
                $result.group.name | Get-Unique | Should -Be "My Company\\MyGroup"
            }

            It 'Should contain subgroups' {
                $result = Get-SEPComputers -GroupName "My Company\\MyGroup" -IncludeSubGroups
                $result | Should -Not -BeNullOrEmpty
                $result.group.name | Where-Object { $_ -eq "My Company\\MyGroup" } | Should -Not -BeNullOrEmpty
                $result.group.name | Where-Object { $_ -eq "My Company\\MyGroup\\Subgroup" } | Should -Not -BeNullOrEmpty
            }

            It 'Should have the expected type' {
                $result = Get-SEPComputers -GroupName "My Company\\MyGroup"
                $result[0].PSObject.TypeNames[0] | Should -Be 'SEP.Computer'
            }
        }
    }
}

