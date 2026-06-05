[CmdletBinding()]
param()

BeforeDiscovery {
    $moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
    . (Join-Path -Path $moduleRootPath -ChildPath 'Tests/Config/Common-Init.ps1')
}

Describe 'Get-SEPComputers' {
    BeforeAll {
        $moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
        . (Join-Path -Path $moduleRootPath -ChildPath 'Tests/DummyDataGenerator.ps1')
    }

    Context 'No parameters' {
        It 'Should return exactly one page of computers' {
            $fakeSession = [PSCustomObject]@{
                Headers   = @{ Authorization = 'Bearer FakeToken'; Content = 'application/json' }
                BaseURLv1 = 'https://FakeServer01:1234/sepm/api/v1'
                BaseURLv2 = 'https://FakeServer01:1234/sepm/api/v2'
                SkipCert  = $true
                TokenInfo = [PSCustomObject]@{ token = 'FakeToken'; tokenExpiration = (Get-Date).AddHours(1) }
            }

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-ABRestMethod -ModuleName PSSymantecSEPM -ParameterFilter { $params.Method -eq 'GET' } {
                return [PSCustomObject]@{ content = (1..5 | ForEach-Object { New-DummyDataSEPComputers }); firstPage = $false; lastPage = $true }
            }

            $result = Get-SEPComputers
            $result | Should -Not -BeNullOrEmpty
            $result.count | Should -Be 5
            Should -Invoke Invoke-ABRestMethod -ModuleName PSSymantecSEPM -Exactly 1 -Scope It
        }

        It 'Should have the expected type' {
            $fakeSession = [PSCustomObject]@{
                Headers   = @{ Authorization = 'Bearer FakeToken'; Content = 'application/json' }
                BaseURLv1 = 'https://FakeServer01:1234/sepm/api/v1'
                BaseURLv2 = 'https://FakeServer01:1234/sepm/api/v2'
                SkipCert  = $true
                TokenInfo = [PSCustomObject]@{ token = 'FakeToken'; tokenExpiration = (Get-Date).AddHours(1) }
            }

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-ABRestMethod -ModuleName PSSymantecSEPM -ParameterFilter { $params.Method -eq 'GET' } {
                return [PSCustomObject]@{ content = (1..5 | ForEach-Object { New-DummyDataSEPComputers }); firstPage = $false; lastPage = $true }
            }

            $result = Get-SEPComputers
            $result[0].PSObject.TypeNames[0] | Should -Be 'SEP.Computer'
        }
    }

    Context 'With pagination' {
        It 'Should perform exactly 2 API calls to get all computers' {
            $fakeSession = [PSCustomObject]@{
                Headers   = @{ Authorization = 'Bearer FakeToken'; Content = 'application/json' }
                BaseURLv1 = 'https://FakeServer01:1234/sepm/api/v1'
                BaseURLv2 = 'https://FakeServer01:1234/sepm/api/v2'
                SkipCert  = $true
                TokenInfo = [PSCustomObject]@{ token = 'FakeToken'; tokenExpiration = (Get-Date).AddHours(1) }
            }

            $state = @{ callCount = 0 }
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-ABRestMethod -ModuleName PSSymantecSEPM -ParameterFilter { $params.Method -eq 'GET' } {
                $state.callCount++
                if ($state.callCount -ge 2) {
                    return [PSCustomObject]@{ content = (1..5 | ForEach-Object { New-DummyDataSEPComputers }); firstPage = $false; lastPage = $true }
                } else {
                    return [PSCustomObject]@{ content = (1..100 | ForEach-Object { New-DummyDataSEPComputers }); firstPage = $true; lastPage = $false }
                }
            }

            $result = Get-SEPComputers
            $result | Should -Not -BeNullOrEmpty
            Should -Invoke Invoke-ABRestMethod -ModuleName PSSymantecSEPM -Exactly 2 -Scope It
        }
    }

    Context 'ComputerName parameter' {
        It 'Should contain MyComputer only' {
            $fakeSession = [PSCustomObject]@{
                Headers   = @{ Authorization = 'Bearer FakeToken'; Content = 'application/json' }
                BaseURLv1 = 'https://FakeServer01:1234/sepm/api/v1'
                BaseURLv2 = 'https://FakeServer01:1234/sepm/api/v2'
                SkipCert  = $true
                TokenInfo = [PSCustomObject]@{ token = 'FakeToken'; tokenExpiration = (Get-Date).AddHours(1) }
            }

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-ABRestMethod -ModuleName PSSymantecSEPM -ParameterFilter { $params.Method -eq 'GET' } {
                return [PSCustomObject]@{
                    content   = (, @(New-DummyDataSEPComputers -ComputerName "MyComputer")) + (1..4 | ForEach-Object { New-DummyDataSEPComputers })
                    firstPage = $true; lastPage = $true
                }
            }

            $result = Get-SEPComputers -ComputerName "MyComputer"
            $result | Should -Not -BeNullOrEmpty
            $result.computername | Should -Be "MyComputer"
        }

        It 'With Computername from the pipeline' {
            $fakeSession = [PSCustomObject]@{
                Headers   = @{ Authorization = 'Bearer FakeToken'; Content = 'application/json' }
                BaseURLv1 = 'https://FakeServer01:1234/sepm/api/v1'
                BaseURLv2 = 'https://FakeServer01:1234/sepm/api/v2'
                SkipCert  = $true
                TokenInfo = [PSCustomObject]@{ token = 'FakeToken'; tokenExpiration = (Get-Date).AddHours(1) }
            }

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-ABRestMethod -ModuleName PSSymantecSEPM -ParameterFilter { $params.Method -eq 'GET' } {
                return [PSCustomObject]@{
                    content   = (, @(New-DummyDataSEPComputers -ComputerName "MyComputer")) + (1..4 | ForEach-Object { New-DummyDataSEPComputers })
                    firstPage = $true; lastPage = $true
                }
            }

            $result = "MyComputer" | Get-SEPComputers
            $result | Should -Not -BeNullOrEmpty
            $result.computername | Should -Be "MyComputer"
        }

        It 'Should have the expected type' {
            $fakeSession = [PSCustomObject]@{
                Headers   = @{ Authorization = 'Bearer FakeToken'; Content = 'application/json' }
                BaseURLv1 = 'https://FakeServer01:1234/sepm/api/v1'
                BaseURLv2 = 'https://FakeServer01:1234/sepm/api/v2'
                SkipCert  = $true
                TokenInfo = [PSCustomObject]@{ token = 'FakeToken'; tokenExpiration = (Get-Date).AddHours(1) }
            }

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-ABRestMethod -ModuleName PSSymantecSEPM -ParameterFilter { $params.Method -eq 'GET' } {
                return [PSCustomObject]@{
                    content   = (, @(New-DummyDataSEPComputers -ComputerName "MyComputer")) + (1..4 | ForEach-Object { New-DummyDataSEPComputers })
                    firstPage = $true; lastPage = $true
                }
            }

            $result = Get-SEPComputers -ComputerName "MyComputer"
            $result.PSObject.TypeNames[0] | Should -Be 'SEP.Computer'
        }
    }

    Context 'GroupName parameter' {
        It 'Should contain only computers from the group "My Company\\MyGroup"' {
            $fakeSession = [PSCustomObject]@{
                Headers   = @{ Authorization = 'Bearer FakeToken'; Content = 'application/json' }
                BaseURLv1 = 'https://FakeServer01:1234/sepm/api/v1'
                BaseURLv2 = 'https://FakeServer01:1234/sepm/api/v2'
                SkipCert  = $true
                TokenInfo = [PSCustomObject]@{ token = 'FakeToken'; tokenExpiration = (Get-Date).AddHours(1) }
            }

            $state = @{ callCount = 0 }
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-ABRestMethod -ModuleName PSSymantecSEPM -ParameterFilter { $params.Method -eq 'GET' } {
                $state.callCount++
                if ($state.callCount -ge 2) {
                    return [PSCustomObject]@{
                        content = (1..5 | ForEach-Object { New-DummyDataSEPComputers -GroupName "My Company\\MyGroup" }) + (1..5 | ForEach-Object { New-DummyDataSEPComputers -GroupName "My Company\\MyGroup\\Subgroup" })
                        firstPage = $false; lastPage = $true
                    }
                } else {
                    return [PSCustomObject]@{
                        content = (1..5 | ForEach-Object { New-DummyDataSEPComputers -GroupName "My Company\\MyGroup" }) + (1..5 | ForEach-Object { New-DummyDataSEPComputers -GroupName "My Company\\MyGroup\\Subgroup" }) + (1..8 | ForEach-Object { New-DummyDataSEPComputers })
                        firstPage = $true; lastPage = $false
                    }
                }
            }

            $result = Get-SEPComputers -GroupName "My Company\\MyGroup"
            $result | Should -Not -BeNullOrEmpty
            $result.group.name | Get-Unique | Should -Be "My Company\\MyGroup"
        }

        It 'Should contain subgroups' {
            $fakeSession = [PSCustomObject]@{
                Headers   = @{ Authorization = 'Bearer FakeToken'; Content = 'application/json' }
                BaseURLv1 = 'https://FakeServer01:1234/sepm/api/v1'
                BaseURLv2 = 'https://FakeServer01:1234/sepm/api/v2'
                SkipCert  = $true
                TokenInfo = [PSCustomObject]@{ token = 'FakeToken'; tokenExpiration = (Get-Date).AddHours(1) }
            }

            $state = @{ callCount = 0 }
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-ABRestMethod -ModuleName PSSymantecSEPM -ParameterFilter { $params.Method -eq 'GET' } {
                $state.callCount++
                if ($state.callCount -ge 2) {
                    return [PSCustomObject]@{
                        content = (1..5 | ForEach-Object { New-DummyDataSEPComputers -GroupName "My Company\\MyGroup" }) + (1..5 | ForEach-Object { New-DummyDataSEPComputers -GroupName "My Company\\MyGroup\\Subgroup" })
                        firstPage = $false; lastPage = $true
                    }
                } else {
                    return [PSCustomObject]@{
                        content = (1..5 | ForEach-Object { New-DummyDataSEPComputers -GroupName "My Company\\MyGroup" }) + (1..5 | ForEach-Object { New-DummyDataSEPComputers -GroupName "My Company\\MyGroup\\Subgroup" }) + (1..8 | ForEach-Object { New-DummyDataSEPComputers })
                        firstPage = $true; lastPage = $false
                    }
                }
            }

            $result = Get-SEPComputers -GroupName "My Company\\MyGroup" -IncludeSubGroups
            $result | Should -Not -BeNullOrEmpty
            $result.group.name | Where-Object { $_ -eq "My Company\\MyGroup" } | Should -Not -BeNullOrEmpty
            $result.group.name | Where-Object { $_ -eq "My Company\\MyGroup\\Subgroup" } | Should -Not -BeNullOrEmpty
        }

        It 'Should have the expected type' {
            $fakeSession = [PSCustomObject]@{
                Headers   = @{ Authorization = 'Bearer FakeToken'; Content = 'application/json' }
                BaseURLv1 = 'https://FakeServer01:1234/sepm/api/v1'
                BaseURLv2 = 'https://FakeServer01:1234/sepm/api/v2'
                SkipCert  = $true
                TokenInfo = [PSCustomObject]@{ token = 'FakeToken'; tokenExpiration = (Get-Date).AddHours(1) }
            }

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-ABRestMethod -ModuleName PSSymantecSEPM -ParameterFilter { $params.Method -eq 'GET' } {
                return [PSCustomObject]@{ content = (1..5 | ForEach-Object { New-DummyDataSEPComputers -GroupName "My Company\\MyGroup" }); firstPage = $true; lastPage = $true }
            }

            $result = Get-SEPComputers -GroupName "My Company\\MyGroup"
            $result[0].PSObject.TypeNames[0] | Should -Be 'SEP.Computer'
        }
    }

    Context 'URI construction' {
        It 'ComputerName includes computerName query parameter in URI' {
            $fakeSession = [PSCustomObject]@{
                Headers   = @{ Authorization = 'Bearer FakeToken'; Content = 'application/json' }
                BaseURLv1 = 'https://FakeServer01:1234/sepm/api/v1'
                BaseURLv2 = 'https://FakeServer01:1234/sepm/api/v2'
                SkipCert  = $true
                TokenInfo = [PSCustomObject]@{ token = 'FakeToken'; tokenExpiration = (Get-Date).AddHours(1) }
            }

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-ABRestMethod -ModuleName PSSymantecSEPM -ParameterFilter { $params.Method -eq 'GET' } {
                return [PSCustomObject]@{ content = (1..5 | ForEach-Object { New-DummyDataSEPComputers }); firstPage = $true; lastPage = $true }
            }

            Get-SEPComputers -ComputerName "MyComputer" | Out-Null

            Should -Invoke Invoke-ABRestMethod -ModuleName PSSymantecSEPM -Exactly 1 -Scope It -ParameterFilter {
                $params.Uri -match '/computers\?computerName=MyComputer$'
            }
        }

        It 'No parameters includes default sort query in URI' {
            $fakeSession = [PSCustomObject]@{
                Headers   = @{ Authorization = 'Bearer FakeToken'; Content = 'application/json' }
                BaseURLv1 = 'https://FakeServer01:1234/sepm/api/v1'
                BaseURLv2 = 'https://FakeServer01:1234/sepm/api/v2'
                SkipCert  = $true
                TokenInfo = [PSCustomObject]@{ token = 'FakeToken'; tokenExpiration = (Get-Date).AddHours(1) }
            }

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-ABRestMethod -ModuleName PSSymantecSEPM -ParameterFilter { $params.Method -eq 'GET' } {
                return [PSCustomObject]@{ content = (1..5 | ForEach-Object { New-DummyDataSEPComputers }); firstPage = $true; lastPage = $true }
            }

            Get-SEPComputers | Out-Null

            Should -Invoke Invoke-ABRestMethod -ModuleName PSSymantecSEPM -Exactly 1 -Scope It -ParameterFilter {
                $params.Uri -match 'sort=COMPUTER_NAME'
            }
        }
    }
}
