[CmdletBinding()]
param()

Describe 'Send-SEPMCommandActiveScan' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'ComputerName parameter set' {
        BeforeAll {
            $fakeSession = New-TestSession
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Get-SEPComputers -ModuleName PSSymantecSEPM {
                return New-DummyComputer -ComputerName 'TestPC'
            }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{ command_id = 'CMD-ACTIVE-001' }
            }
        }

        It 'POSTs to the correct activescan endpoint' {
            Send-SEPMCommandActiveScan -ComputerName 'TestPC'

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -match '/command-queue/activescan'
            }
        }

        It 'includes computer_ids in URI query string' {
            Mock Get-SEPComputers -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ uniqueId = 'ABCD1234'; computerName = 'TargetPC' }
            }

            Send-SEPMCommandActiveScan -ComputerName 'TargetPC'

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -match 'computer_ids=ABCD1234'
            }
        }
    }

    Context 'GroupName parameter set' {
        BeforeAll {
            $fakeSession = New-TestSession
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ id = 'GRP-5678'; fullPathName = 'My Company\TestGroup' }
            }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{ command_id = 'CMD-GROUP-001' }
            }
        }

        It 'POSTs to activescan endpoint with group_ids in URI' {
            Send-SEPMCommandActiveScan -GroupName 'My Company\TestGroup'

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -match '/command-queue/activescan' -and $Uri -match 'group_ids=GRP-5678'
            }
        }

        It 'returns the API response' {
            $result = Send-SEPMCommandActiveScan -GroupName 'My Company\TestGroup'

            $result | Should -Not -BeNullOrEmpty
            $result.command_id | Should -Be 'CMD-GROUP-001'
        }
    }
}
