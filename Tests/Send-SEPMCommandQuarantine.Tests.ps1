[CmdletBinding()]
param()

Describe 'Send-SEPMCommandQuarantine' {
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

        It 'POSTs to the quarantine endpoint for a given computer name' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{ status = 'success' }
            }
            Mock Build-SEPMQueryURI -ModuleName PSSymantecSEPM {
                return 'https://FakeServer01:1234/sepm/api/v1/command-queue/quarantine?computer_ids=12345'
            }

            $result = Send-SEPMCommandQuarantine -ComputerName 'TEST-PC'
            $result.status | Should -Be 'success'

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Exactly 1 -Scope It -ParameterFilter {
                $Method -eq 'POST' -and
                $Uri -match '/command-queue/quarantine'
            }
        }

        It 'passes computer_ids as a query parameter to Build-SEPMQueryURI' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM { return @{ ok = $true } }
            Mock Build-SEPMQueryURI -ModuleName PSSymantecSEPM { return 'mocked-uri' }

            Send-SEPMCommandQuarantine -ComputerName 'TEST-PC' | Out-Null

            Should -Invoke Build-SEPMQueryURI -ModuleName PSSymantecSEPM -Exactly 1 -Scope It -ParameterFilter {
                $QueryStrings.computer_ids -contains '12345'
            }
        }

        It 'adds undo=true query param when Unquarantine is specified' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM { return @{ ok = $true } }
            Mock Build-SEPMQueryURI -ModuleName PSSymantecSEPM { return 'mocked-uri' }

            Send-SEPMCommandQuarantine -ComputerName 'TEST-PC' -Unquarantine | Out-Null

            Should -Invoke Build-SEPMQueryURI -ModuleName PSSymantecSEPM -Exactly 1 -Scope It -ParameterFilter {
                $QueryStrings['undo'] -eq $true
            }
        }

        It 'omits undo param when Unquarantine is not specified' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM { return @{ ok = $true } }
            Mock Build-SEPMQueryURI -ModuleName PSSymantecSEPM { return 'mocked-uri' }

            Send-SEPMCommandQuarantine -ComputerName 'TEST-PC' | Out-Null

            Should -Invoke Build-SEPMQueryURI -ModuleName PSSymantecSEPM -Exactly 1 -Scope It -ParameterFilter {
                -not $QueryStrings.ContainsKey('undo')
            }
        }
    }

    Context 'GroupName' {
        BeforeAll {
            $script:dummyGroup = [PSCustomObject]@{
                id           = 'group-001'
                fullPathName = 'My Company\TestGroup'
            }

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM {
                return New-TestSession
            }
            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM {
                return $script:dummyGroup
            }
        }

        It 'POSTs to the quarantine endpoint for a given group name' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{ status = 'success' }
            }
            Mock Build-SEPMQueryURI -ModuleName PSSymantecSEPM {
                return 'https://FakeServer01:1234/sepm/api/v1/command-queue/quarantine?group_ids=group-001'
            }

            $result = Send-SEPMCommandQuarantine -GroupName 'My Company\TestGroup'
            $result.status | Should -Be 'success'

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Exactly 1 -Scope It -ParameterFilter {
                $Method -eq 'POST' -and
                $Uri -match '/command-queue/quarantine'
            }
        }

        It 'passes group_ids as a query parameter' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM { return @{ ok = $true } }
            Mock Build-SEPMQueryURI -ModuleName PSSymantecSEPM { return 'mocked-uri' }

            Send-SEPMCommandQuarantine -GroupName 'My Company\TestGroup' | Out-Null

            Should -Invoke Build-SEPMQueryURI -ModuleName PSSymantecSEPM -Exactly 1 -Scope It -ParameterFilter {
                $QueryStrings.group_ids -eq 'group-001'
            }
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
            Mock Build-SEPMQueryURI -ModuleName PSSymantecSEPM { return 'https://FakeServer01:1234/sepm/api/v1/command-queue/quarantine?computer_ids=' }

            $result = Send-SEPMCommandQuarantine -ComputerName 'NONEXISTENT-PC'
            $result['ok'] | Should -BeTrue

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Exactly 1 -Scope It -ParameterFilter {
                $Method -eq 'POST' -and
                $Uri -match '/command-queue/quarantine'
            }
        }

        It 'propagates API error response to caller' {
            Mock Get-SEPComputers -ModuleName PSSymantecSEPM { return @() }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM { return @{ error = 'Computer not found' } }
            Mock Build-SEPMQueryURI -ModuleName PSSymantecSEPM { return 'mocked-uri' }

            $result = Send-SEPMCommandQuarantine -ComputerName 'NONEXISTENT-PC'
            $result['error'] | Should -Be 'Computer not found'

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Exactly 1 -Scope It
        }
    }
}
