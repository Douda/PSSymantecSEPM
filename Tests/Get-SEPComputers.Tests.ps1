[CmdletBinding()]
param()

# Build & Load the module
$moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
. (Join-Path -Path $moduleRootPath -ChildPath 'Tests/Config/Common-Init.ps1')

# Store repo root in env var so InModuleScope can access it (Pester isolates module scope)
$env:SEPM_REPO_ROOT = $moduleRootPath

Describe 'Get-SEPComputers' {
    InModuleScope PSSymantecSEPM {
        # Dot-source dummy data generator inside InModuleScope so mocks can use it
        . (Join-Path -Path $env:SEPM_REPO_ROOT -ChildPath 'Tests/DummyDataGenerator.ps1')

        # Shared fake session fixture (must be inside InModuleScope for Pester scoping)
        $fakeSession = [PSCustomObject]@{
            Headers = @{
                'Authorization' = 'Bearer FakeToken'
                'Content'       = 'application/json'
            }
            BaseURLv1 = 'https://FakeServer01:1234/sepm/api/v1'
            BaseURLv2 = 'https://FakeServer01:1234/sepm/api/v2'
        } 
        BeforeAll {
            $moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests/Config/Common-BeforeAll.ps1')
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests/Config/Common-TestEnvironmentSetup.ps1')
        }

        AfterAll {
            $moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests/Config/Common-AfterAll.ps1')
        }

        Context 'No parameters' {
            BeforeAll {
                Mock Initialize-SEPMSession -ModuleName $script:moduleName { return $fakeSession }

                # API Call - single page with 5 computers
                Mock Invoke-ABRestMethod -ModuleName $script:moduleName {
                    return [PSCustomObject]@{
                        content   = (1..5 | ForEach-Object { New-DummyDataSEPComputers })
                        firstPage = $true
                        lastPage  = $true
                    }
                }
            }

            It 'Should return exactly one page of computers' {
                $result = Get-SEPComputers
                $result | Should -Not -BeNullOrEmpty
                $result.count | Should -Be 5
                Assert-MockCalled Invoke-ABRestMethod -ModuleName $script:moduleName -Exactly 1 -Scope It
            }

            It 'Should have the expected type' {
                $result = Get-SEPComputers
                $result[0].PSObject.TypeNames[0] | Should -Be 'SEP.Computer'
            }
        }

        Context 'With pagination' {
            BeforeAll {
                Mock Initialize-SEPMSession -ModuleName $script:moduleName { return $fakeSession }

                $script:callCount = 0
                Mock Invoke-ABRestMethod -ModuleName $script:moduleName {
                    $script:callCount++
                    if ($script:callCount -ge 2) {
                        return [PSCustomObject]@{
                            content   = (1..5 | ForEach-Object { New-DummyDataSEPComputers })
                            firstPage = $false
                            lastPage  = $true
                        }
                    } else {
                        return [PSCustomObject]@{
                            content   = (1..100 | ForEach-Object { New-DummyDataSEPComputers })
                            firstPage = $true
                            lastPage  = $false
                        }
                    }
                }
            }

            It 'Should perform exactly 2 API calls to get all computers' {
                $result = Get-SEPComputers
                $result | Should -Not -BeNullOrEmpty
                Assert-MockCalled Invoke-ABRestMethod -ModuleName $script:moduleName -Exactly 2 -Scope It
            }
        }

        Context 'ComputerName parameter' {
            BeforeAll {
                Mock Initialize-SEPMSession -ModuleName $script:moduleName { return $fakeSession }

                Mock Invoke-ABRestMethod -ModuleName $script:moduleName {
                    return [PSCustomObject]@{
                        content   = (, @(New-DummyDataSEPComputers -ComputerName "MyComputer")) +
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
                Mock Initialize-SEPMSession -ModuleName $script:moduleName { return $fakeSession }

                $script:callCount = 0
                Mock Invoke-ABRestMethod -ModuleName $script:moduleName {
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
