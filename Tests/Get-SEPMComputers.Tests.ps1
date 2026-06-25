[CmdletBinding()]
param()

Describe 'Get-SEPMComputers' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'No parameters' {
        BeforeEach {
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return New-TestSession }
        }

        It 'Should return exactly one page of computers' {
            Mock Invoke-SepmEndpoint -ModuleName PSSymantecSEPM {
                return 1..5 | ForEach-Object { New-DummyComputer }
            }

            $result = Get-SEPMComputers
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 5
            Should -Invoke Invoke-SepmEndpoint -ModuleName PSSymantecSEPM -Exactly 1 -Scope It
        }
    }

    Context 'ComputerName parameter' {
        It 'Should contain MyComputer only' {
            $null = Set-TestMocks -Transport {
                return @{
                    content   = @(New-DummyComputer -ComputerName "MyComputer") + (1..4 | ForEach-Object { New-DummyComputer })
                    lastPage  = $true
                    totalPages = 1
                }
            }

            $result = Get-SEPMComputers -ComputerName "MyComputer"
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 1
            $result[0].computerName | Should -Be "MyComputer"
        }

        It 'With Computername from the pipeline' {
            $null = Set-TestMocks -Transport {
                return @{
                    content   = @(New-DummyComputer -ComputerName "MyComputer") + (1..4 | ForEach-Object { New-DummyComputer })
                    lastPage  = $true
                    totalPages = 1
                }
            }

            $result = "MyComputer" | Get-SEPMComputers
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 1
            $result[0].computerName | Should -Be "MyComputer"
        }
    }

    Context 'GroupName parameter' {
        It 'Should accept GroupName from the pipeline (via ForEach-Object)' {
            $null = Set-TestMocks -Transport {
                return @{
                    content   = 1..5 | ForEach-Object { New-DummyComputer -GroupName 'My Company\Workstations' }
                    lastPage  = $true
                    totalPages = 1
                }
            }

            $result = 'My Company\Workstations' | ForEach-Object { Get-SEPMComputers -GroupName $_ }
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 5
            $result[0].group.name | Should -Be 'My Company\Workstations'
        }

        It 'Should accept GroupName from the pipeline with -IncludeSubGroups' {
            $null = Set-TestMocks -Transport {
                $a = 1..5 | ForEach-Object { New-DummyComputer -GroupName 'My Company\Workstations' }
                $b = 1..3 | ForEach-Object { New-DummyComputer -GroupName 'My Company\Workstations\Sub' }
                return @{ content = $a + $b; lastPage = $true; totalPages = 1 }
            }

            $result = 'My Company\Workstations' | ForEach-Object { Get-SEPMComputers -GroupName $_ -IncludeSubGroups }
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 8
        }

        It 'Should contain only computers from the group "My Company\\MyGroup"' {
            $null = Set-TestMocks -Transport {
                $a = 1..5 | ForEach-Object { New-DummyComputer -GroupName "My Company\\MyGroup" }
                $b = 1..5 | ForEach-Object { New-DummyComputer -GroupName "My Company\\MyGroup\\Subgroup" }
                $c = 1..8 | ForEach-Object { New-DummyComputer }
                return @{ content = $a + $b + $c; lastPage = $true; totalPages = 1 }
            }

            $result = Get-SEPMComputers -GroupName "My Company\\MyGroup"
            $result | Should -Not -BeNullOrEmpty
            $result.group.name | Get-Unique | Should -Be "My Company\\MyGroup"
        }

        It 'Should contain subgroups' {
            $null = Set-TestMocks -Transport {
                $a = 1..5 | ForEach-Object { New-DummyComputer -GroupName "My Company\\MyGroup" }
                $b = 1..5 | ForEach-Object { New-DummyComputer -GroupName "My Company\\MyGroup\\Subgroup" }
                $c = 1..8 | ForEach-Object { New-DummyComputer }
                return @{ content = $a + $b + $c; lastPage = $true; totalPages = 1 }
            }

            $result = Get-SEPMComputers -GroupName "My Company\\MyGroup" -IncludeSubGroups
            $result | Should -Not -BeNullOrEmpty
            $result.group.name | Where-Object { $_ -eq "My Company\\MyGroup" } | Should -Not -BeNullOrEmpty
            $result.group.name | Where-Object { $_ -eq "My Company\\MyGroup\\Subgroup" } | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Invoke-SepmEndpoint parameters' {
        BeforeEach {
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return New-TestSession }
        }

        It 'ComputerName path passes BoundParameters to Invoke-SepmEndpoint' {
            Mock Invoke-SepmEndpoint -ModuleName PSSymantecSEPM {
                return 1..5 | ForEach-Object { New-DummyComputer }
            }

            Get-SEPMComputers -ComputerName "MyComputer" | Out-Null

            Should -Invoke Invoke-SepmEndpoint -ModuleName PSSymantecSEPM -Exactly 1 -Scope It -ParameterFilter {
                $BoundParameters -and $BoundParameters.ContainsKey('ComputerName')
            }
        }

        It 'No parameters does not pass BoundParameters to Invoke-SepmEndpoint' {
            Mock Invoke-SepmEndpoint -ModuleName PSSymantecSEPM {
                return 1..5 | ForEach-Object { New-DummyComputer }
            }

            Get-SEPMComputers | Out-Null

            Should -Invoke Invoke-SepmEndpoint -ModuleName PSSymantecSEPM -Exactly 1 -Scope It -ParameterFilter {
                -not $BoundParameters -or $BoundParameters.Count -eq 0
            }
        }
    }
}
