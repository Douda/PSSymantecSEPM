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
        It 'Should return exactly one page of computers' {
            $fakeSession = New-TestSession -SkipCert

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-SepmEndpoint -ModuleName PSSymantecSEPM {
                return 1..5 | ForEach-Object { New-DummyComputer }
            }

            $result = Get-SEPMComputers
            $result | Should -Not -BeNullOrEmpty
            $result.count | Should -Be 5
            Should -Invoke Invoke-SepmEndpoint -ModuleName PSSymantecSEPM -Exactly 1 -Scope It
        }
    }

    Context 'ComputerName parameter' {
        It 'Should contain MyComputer only' {
            $fakeSession = New-TestSession -SkipCert

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-SepmEndpoint -ModuleName PSSymantecSEPM {
                return @(New-DummyComputer -ComputerName "MyComputer") + (1..4 | ForEach-Object { New-DummyComputer })
            }

            $result = Get-SEPMComputers -ComputerName "MyComputer"
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 1
            $result[0].computername | Should -Be "MyComputer"
        }

        It 'With Computername from the pipeline' {
            $fakeSession = New-TestSession -SkipCert

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-SepmEndpoint -ModuleName PSSymantecSEPM {
                return @(New-DummyComputer -ComputerName "MyComputer") + (1..4 | ForEach-Object { New-DummyComputer })
            }

            $result = "MyComputer" | Get-SEPMComputers
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 1
            $result[0].computername | Should -Be "MyComputer"
        }
    }

    Context 'GroupName parameter' {
        It 'Should accept GroupName from the pipeline (via ForEach-Object)' {
            $fakeSession = New-TestSession -SkipCert

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-SepmEndpoint -ModuleName PSSymantecSEPM {
                return 1..5 | ForEach-Object { New-DummyComputer -GroupName 'My Company\Workstations' }
            }

            $result = 'My Company\Workstations' | ForEach-Object { Get-SEPMComputers -GroupName $_ }
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 5
            $result[0].group.name | Should -Be 'My Company\Workstations'
        }

        It 'Should accept GroupName from the pipeline with -IncludeSubGroups' {
            $fakeSession = New-TestSession -SkipCert

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-SepmEndpoint -ModuleName PSSymantecSEPM {
                $a = 1..5 | ForEach-Object { New-DummyComputer -GroupName 'My Company\Workstations' }
                $b = 1..3 | ForEach-Object { New-DummyComputer -GroupName 'My Company\Workstations\Sub' }
                return $a + $b
            }

            $result = 'My Company\Workstations' | ForEach-Object { Get-SEPMComputers -GroupName $_ -IncludeSubGroups }
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 8
        }
        It 'Should contain only computers from the group "My Company\\MyGroup"' {
            $fakeSession = New-TestSession -SkipCert

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-SepmEndpoint -ModuleName PSSymantecSEPM {
                return (1..5 | ForEach-Object { New-DummyComputer -GroupName "My Company\\MyGroup" }) + (1..5 | ForEach-Object { New-DummyComputer -GroupName "My Company\\MyGroup\\Subgroup" }) + (1..8 | ForEach-Object { New-DummyComputer })
            }

            $result = Get-SEPMComputers -GroupName "My Company\\MyGroup"
            $result | Should -Not -BeNullOrEmpty
            $result.group.name | Get-Unique | Should -Be "My Company\\MyGroup"
        }

        It 'Should contain subgroups' {
            $fakeSession = New-TestSession -SkipCert

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-SepmEndpoint -ModuleName PSSymantecSEPM {
                return (1..5 | ForEach-Object { New-DummyComputer -GroupName "My Company\\MyGroup" }) + (1..5 | ForEach-Object { New-DummyComputer -GroupName "My Company\\MyGroup\\Subgroup" }) + (1..8 | ForEach-Object { New-DummyComputer })
            }

            $result = Get-SEPMComputers -GroupName "My Company\\MyGroup" -IncludeSubGroups
            $result | Should -Not -BeNullOrEmpty
            $result.group.name | Where-Object { $_ -eq "My Company\\MyGroup" } | Should -Not -BeNullOrEmpty
            $result.group.name | Where-Object { $_ -eq "My Company\\MyGroup\\Subgroup" } | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Invoke-SepmEndpoint parameters' {
        It 'ComputerName path passes BoundParameters to Invoke-SepmEndpoint' {
            $fakeSession = New-TestSession -SkipCert

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-SepmEndpoint -ModuleName PSSymantecSEPM {
                return 1..5 | ForEach-Object { New-DummyComputer }
            }

            Get-SEPMComputers -ComputerName "MyComputer" | Out-Null

            Should -Invoke Invoke-SepmEndpoint -ModuleName PSSymantecSEPM -Exactly 1 -Scope It -ParameterFilter {
                $BoundParameters -and $BoundParameters.ContainsKey('ComputerName')
            }
        }

        It 'No parameters does not pass BoundParameters to Invoke-SepmEndpoint' {
            $fakeSession = New-TestSession -SkipCert

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
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
