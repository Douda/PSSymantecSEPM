[CmdletBinding()]
param()

Describe 'Get-SEPComputers' {
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
                return @{ content = (1..5 | ForEach-Object { New-DummyComputer }); lastPage = $true }
            }

            $result = Get-SEPComputers
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
                return @{
                    content   = (, @(New-DummyComputer -ComputerName "MyComputer")) + (1..4 | ForEach-Object { New-DummyComputer })
                    lastPage = $true
                }
            }

            $result = Get-SEPComputers -ComputerName "MyComputer"
            $result | Should -Not -BeNullOrEmpty
            $result.computername | Should -Be "MyComputer"
        }

        It 'With Computername from the pipeline' {
            $fakeSession = New-TestSession -SkipCert

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-SepmEndpoint -ModuleName PSSymantecSEPM {
                return @{
                    content   = (, @(New-DummyComputer -ComputerName "MyComputer")) + (1..4 | ForEach-Object { New-DummyComputer })
                    lastPage = $true
                }
            }

            $result = "MyComputer" | Get-SEPComputers
            $result | Should -Not -BeNullOrEmpty
            $result.computername | Should -Be "MyComputer"
        }
    }

    Context 'GroupName parameter' {
        It 'Should contain only computers from the group "My Company\\MyGroup"' {
            $fakeSession = New-TestSession -SkipCert

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-SepmEndpoint -ModuleName PSSymantecSEPM {
                return @{
                    content = (1..5 | ForEach-Object { New-DummyComputer -GroupName "My Company\\MyGroup" }) + (1..5 | ForEach-Object { New-DummyComputer -GroupName "My Company\\MyGroup\\Subgroup" }) + (1..8 | ForEach-Object { New-DummyComputer })
                    lastPage = $true
                }
            }

            $result = Get-SEPComputers -GroupName "My Company\\MyGroup"
            $result | Should -Not -BeNullOrEmpty
            $result.group.name | Get-Unique | Should -Be "My Company\\MyGroup"
        }

        It 'Should contain subgroups' {
            $fakeSession = New-TestSession -SkipCert

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-SepmEndpoint -ModuleName PSSymantecSEPM {
                return @{
                    content = (1..5 | ForEach-Object { New-DummyComputer -GroupName "My Company\\MyGroup" }) + (1..5 | ForEach-Object { New-DummyComputer -GroupName "My Company\\MyGroup\\Subgroup" }) + (1..8 | ForEach-Object { New-DummyComputer })
                    lastPage = $true
                }
            }

            $result = Get-SEPComputers -GroupName "My Company\\MyGroup" -IncludeSubGroups
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
                return @{ content = (1..5 | ForEach-Object { New-DummyComputer }); lastPage = $true }
            }

            Get-SEPComputers -ComputerName "MyComputer" | Out-Null

            Should -Invoke Invoke-SepmEndpoint -ModuleName PSSymantecSEPM -Exactly 1 -Scope It -ParameterFilter {
                $BoundParameters -and $BoundParameters.ContainsKey('ComputerName')
            }
        }

        It 'No parameters does not pass BoundParameters to Invoke-SepmEndpoint' {
            $fakeSession = New-TestSession -SkipCert

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-SepmEndpoint -ModuleName PSSymantecSEPM {
                return @{ content = (1..5 | ForEach-Object { New-DummyComputer }); lastPage = $true }
            }

            Get-SEPComputers | Out-Null

            Should -Invoke Invoke-SepmEndpoint -ModuleName PSSymantecSEPM -Exactly 1 -Scope It -ParameterFilter {
                -not $BoundParameters -or $BoundParameters.Count -eq 0
            }
        }
    }
}
