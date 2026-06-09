[CmdletBinding()]
param()

Describe 'Update-SEPClientDefinitions' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'ComputerName' {
        BeforeAll {
            $script:dummyComputer = [PSCustomObject]@{
                uniqueId     = '12345'
                computerName = 'TEST-PC'
            }

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM {
                return New-TestSession
            }
            Mock Get-SEPComputers -ModuleName PSSymantecSEPM {
                return $script:dummyComputer
            }
        }

        It 'POSTs to the updatecontent endpoint for a given computer name' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{ status = 'success' }
            }
            Mock Build-SEPMQueryURI -ModuleName PSSymantecSEPM {
                return 'https://FakeServer01:1234/sepm/api/v1/command-queue/updatecontent?computer_ids=12345'
            }

            $result = Update-SEPClientDefinitions -ComputerName 'TEST-PC'
            $result['status'] | Should -Be 'success'

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Exactly 1 -Scope It -ParameterFilter {
                $Method -eq 'POST' -and
                $Uri -match '/command-queue/updatecontent'
            }
        }

        It 'passes computer_ids to Build-SEPMQueryURI' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM { return @{ ok = $true } }
            Mock Build-SEPMQueryURI -ModuleName PSSymantecSEPM { return 'mocked-uri' }

            Update-SEPClientDefinitions -ComputerName 'TEST-PC' | Out-Null

            Should -Invoke Build-SEPMQueryURI -ModuleName PSSymantecSEPM -Exactly 1 -Scope It -ParameterFilter {
                $QueryStrings.computer_ids -contains '12345'
            }
        }
    }

    Context 'GroupName' {
        BeforeAll {
            $script:fakeComputers = @(
                [PSCustomObject]@{ uniqueId = 'comp-A'; group = [PSCustomObject]@{ name = 'My Company\TestGroup' } }
                [PSCustomObject]@{ uniqueId = 'comp-B'; group = [PSCustomObject]@{ name = 'My Company\TestGroup' } }
                [PSCustomObject]@{ uniqueId = 'comp-C'; group = [PSCustomObject]@{ name = 'My Company\TestGroup\Sub' } }
            )

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM {
                return New-TestSession
            }
        }

        It 'sends individual POST per computer in group (non-recursive)' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                if ($Method -eq 'GET') {
                    return @{
                        content  = $script:fakeComputers
                        lastPage = $true
                    }
                }
                return @{ status = 'success' }
            }
            Mock Build-SEPMQueryURI -ModuleName PSSymantecSEPM {
                return 'https://fake/sepm/api/v1/command-queue/updatecontent?computer_ids=someid'
            }

            $result = Update-SEPClientDefinitions -GroupName 'My Company\TestGroup'

            $result.Count | Should -Be 2
            $result[0]['status'] | Should -Be 'success'
            $result[1]['status'] | Should -Be 'success'
        }

        It 'filters by -eq for non-recursive group lookup' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                if ($Method -eq 'GET') {
                    return @{
                        content  = $script:fakeComputers
                        lastPage = $true
                    }
                }
                return @{ status = 'success' }
            }
            Mock Build-SEPMQueryURI -ModuleName PSSymantecSEPM {
                return 'https://fake/sepm/api/v1/command-queue/updatecontent?computer_ids=someid'
            }

            $result = Update-SEPClientDefinitions -GroupName 'My Company\TestGroup'
            $result.Count | Should -Be 2
        }

        It 'includes subgroups when IncludeSubGroups is specified' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                if ($Method -eq 'GET') {
                    return @{
                        content  = $script:fakeComputers
                        lastPage = $true
                    }
                }
                return @{ status = 'success' }
            }
            Mock Build-SEPMQueryURI -ModuleName PSSymantecSEPM {
                return 'https://fake/sepm/api/v1/command-queue/updatecontent?computer_ids=someid'
            }

            $result = Update-SEPClientDefinitions -GroupName 'My Company\TestGroup' -IncludeSubGroups
            $result.Count | Should -Be 3
        }
    }

    Context 'Error handling' {
        BeforeAll {
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM {
                return New-TestSession
            }
        }

        It 'still dispatches command for non-existent computer (API validates)' {
            Mock Get-SEPComputers -ModuleName PSSymantecSEPM { return @() }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM { return @{ ok = $true } }
            Mock Build-SEPMQueryURI -ModuleName PSSymantecSEPM { return 'mocked-uri' }

            $result = Update-SEPClientDefinitions -ComputerName 'NONEXISTENT-PC'
            $result['ok'] | Should -BeTrue

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Exactly 1 -Scope It -ParameterFilter {
                $Method -eq 'POST'
            }
        }

        It 'propagates API error for non-existent computer' {
            Mock Get-SEPComputers -ModuleName PSSymantecSEPM { return @() }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM { return @{ error = 'Computer not found' } }
            Mock Build-SEPMQueryURI -ModuleName PSSymantecSEPM { return 'mocked-uri' }

            $result = Update-SEPClientDefinitions -ComputerName 'NONEXISTENT-PC'
            $result['error'] | Should -Be 'Computer not found'
        }
    }
}
