[CmdletBinding()]
param()

Describe 'Get-SEPComputers' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment

        InModuleScope PSSymantecSEPM {
            $script:configurationFilePath = Join-Path -Path 'TestDrive:' -ChildPath 'config.json'
            $script:credentialsFilePath   = Join-Path -Path 'TestDrive:' -ChildPath 'creds.xml'
            $script:accessTokenFilePath   = Join-Path -Path 'TestDrive:' -ChildPath 'token.xml'
        }
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'No parameters' {
        It 'Should return exactly one page of computers' {
            $fakeSession = New-TestSession -SkipCert

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter { $Method -eq 'GET' } {
                return @{ content = (1..5 | ForEach-Object { New-DummyComputer }); firstPage = $false; lastPage = $true }
            }

            $result = Get-SEPComputers
            $result | Should -Not -BeNullOrEmpty
            $result.count | Should -Be 5
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Exactly 1 -Scope It
        }
    }

    Context 'With pagination' {
        It 'Should perform exactly 2 API calls to get all computers' {
            $fakeSession = New-TestSession -SkipCert

            $state = @{ callCount = 0 }
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter { $Method -eq 'GET' } {
                $state.callCount++
                if ($state.callCount -ge 2) {
                    return @{ content = (1..5 | ForEach-Object { New-DummyComputer }); firstPage = $false; lastPage = $true }
                } else {
                    return @{ content = (1..100 | ForEach-Object { New-DummyComputer }); firstPage = $true; lastPage = $false }
                }
            }

            $result = Get-SEPComputers
            $result | Should -Not -BeNullOrEmpty
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Exactly 2 -Scope It
        }
    }

    Context 'ComputerName parameter' {
        It 'Should contain MyComputer only' {
            $fakeSession = New-TestSession -SkipCert

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter { $Method -eq 'GET' } {
                return @{
                    content   = (, @(New-DummyComputer -ComputerName "MyComputer")) + (1..4 | ForEach-Object { New-DummyComputer })
                    firstPage = $true; lastPage = $true
                }
            }

            $result = Get-SEPComputers -ComputerName "MyComputer"
            $result | Should -Not -BeNullOrEmpty
            $result.computername | Should -Be "MyComputer"
        }

        It 'With Computername from the pipeline' {
            $fakeSession = New-TestSession -SkipCert

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter { $Method -eq 'GET' } {
                return @{
                    content   = (, @(New-DummyComputer -ComputerName "MyComputer")) + (1..4 | ForEach-Object { New-DummyComputer })
                    firstPage = $true; lastPage = $true
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

            $state = @{ callCount = 0 }
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter { $Method -eq 'GET' } {
                $state.callCount++
                if ($state.callCount -ge 2) {
                    return @{
                        content = (1..5 | ForEach-Object { New-DummyComputer -GroupName "My Company\\MyGroup" }) + (1..5 | ForEach-Object { New-DummyComputer -GroupName "My Company\\MyGroup\\Subgroup" })
                        firstPage = $false; lastPage = $true
                    }
                } else {
                    return @{
                        content = (1..5 | ForEach-Object { New-DummyComputer -GroupName "My Company\\MyGroup" }) + (1..5 | ForEach-Object { New-DummyComputer -GroupName "My Company\\MyGroup\\Subgroup" }) + (1..8 | ForEach-Object { New-DummyComputer })
                        firstPage = $true; lastPage = $false
                    }
                }
            }

            $result = Get-SEPComputers -GroupName "My Company\\MyGroup"
            $result | Should -Not -BeNullOrEmpty
            $result.group.name | Get-Unique | Should -Be "My Company\\MyGroup"
        }

        It 'Should contain subgroups' {
            $fakeSession = New-TestSession -SkipCert

            $state = @{ callCount = 0 }
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter { $Method -eq 'GET' } {
                $state.callCount++
                if ($state.callCount -ge 2) {
                    return @{
                        content = (1..5 | ForEach-Object { New-DummyComputer -GroupName "My Company\\MyGroup" }) + (1..5 | ForEach-Object { New-DummyComputer -GroupName "My Company\\MyGroup\\Subgroup" })
                        firstPage = $false; lastPage = $true
                    }
                } else {
                    return @{
                        content = (1..5 | ForEach-Object { New-DummyComputer -GroupName "My Company\\MyGroup" }) + (1..5 | ForEach-Object { New-DummyComputer -GroupName "My Company\\MyGroup\\Subgroup" }) + (1..8 | ForEach-Object { New-DummyComputer })
                        firstPage = $true; lastPage = $false
                    }
                }
            }

            $result = Get-SEPComputers -GroupName "My Company\\MyGroup" -IncludeSubGroups
            $result | Should -Not -BeNullOrEmpty
            $result.group.name | Where-Object { $_ -eq "My Company\\MyGroup" } | Should -Not -BeNullOrEmpty
            $result.group.name | Where-Object { $_ -eq "My Company\\MyGroup\\Subgroup" } | Should -Not -BeNullOrEmpty
        }
    }

    Context 'URI construction' {
        It 'ComputerName includes computerName query parameter in URI' {
            $fakeSession = New-TestSession -SkipCert

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter { $Method -eq 'GET' } {
                return @{ content = (1..5 | ForEach-Object { New-DummyComputer }); firstPage = $true; lastPage = $true }
            }

            Get-SEPComputers -ComputerName "MyComputer" | Out-Null

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Exactly 1 -Scope It -ParameterFilter {
                $Uri -match '/computers\?computerName=MyComputer$'
            }
        }

        It 'No parameters includes default sort query in URI' {
            $fakeSession = New-TestSession -SkipCert

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter { $Method -eq 'GET' } {
                return @{ content = (1..5 | ForEach-Object { New-DummyComputer }); firstPage = $true; lastPage = $true }
            }

            Get-SEPComputers | Out-Null

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Exactly 1 -Scope It -ParameterFilter {
                $Uri -match 'sort=COMPUTER_NAME'
            }
        }
    }
}
