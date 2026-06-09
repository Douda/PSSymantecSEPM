[CmdletBinding()]
param()

Describe 'Send-SEPMCommandFullScan' {
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
                return [PSCustomObject]@{ uniqueId = 'ABCD1234'; computerName = 'TestPC' }
            }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{ command_id = 'CMD-FULL-001' }
            }
        }

        It 'POSTs to the correct fullscan endpoint' {
            Send-SEPMCommandFullScan -ComputerName 'TestPC'

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -match '/command-queue/fullscan'
            }
        }

        It 'includes computer_ids in URI query string' {
            Send-SEPMCommandFullScan -ComputerName 'TestPC'

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -match 'computer_ids=ABCD1234'
            }
        }

        It 'returns the API response' {
            $result = Send-SEPMCommandFullScan -ComputerName 'TestPC'

            $result | Should -Not -BeNullOrEmpty
            $result.command_id | Should -Be 'CMD-FULL-001'
        }
    }

    Context 'GroupName parameter set' {
        BeforeAll {
            $fakeSession = New-TestSession
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ id = 'GRP-9012'; fullPathName = 'My Company\\Servers' }
            }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{ command_id = 'CMD-FULL-GROUP-001' }
            }
        }

        It 'POSTs to fullscan endpoint with group_ids in URI' {
            Send-SEPMCommandFullScan -GroupName 'My Company\\Servers'

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -match '/command-queue/fullscan' -and $Uri -match 'group_ids=GRP-9012'
            }
        }
    }
}
