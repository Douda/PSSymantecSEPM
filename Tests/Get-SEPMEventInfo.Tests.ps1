[CmdletBinding()]
param()

Describe 'Get-SEPMEventInfo' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'happy path' {
        BeforeAll {
            $fakeSession = New-TestSession
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
        }

        It 'returns critical events list with SEPM.EventInfo type' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{
                    criticalEventsInfoList = @(
                        @{
                            eventId       = 'EVT001'
                            eventDateTime = '2026-06-07 17:29:07.0'
                            subject       = 'CRITICAL: OLD SONAR DEFINITIONS'
                            message       = '306 computers found with old definitions.'
                            acknowledged  = 0
                        },
                        @{
                            eventId       = 'EVT002'
                            eventDateTime = '2026-06-08 10:15:00.0'
                            subject       = 'CRITICAL: MISSING UPDATES'
                            message       = 'Server out of date.'
                            acknowledged  = 1
                        }
                    )
                    totalUnacknowledgedMessages = 2
                }
            }

            $result = Get-SEPMEventInfo
            $result.Count | Should -Be 2
            $result[0].eventId  | Should -Be 'EVT001'
            $result[1].eventId  | Should -Be 'EVT002'
            $result[0].PSObject.TypeNames[0] | Should -Be 'SEPM.EventInfo'
        }

        It 'calls the correct API endpoint' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{ criticalEventsInfoList = @(); totalUnacknowledgedMessages = 0 }
            }

            Get-SEPMEventInfo | Out-Null
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'GET' -and $Uri -match '/events/critical$'
            }
        }

        It 'handles empty critical events list gracefully' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{ criticalEventsInfoList = @(); totalUnacknowledgedMessages = 0 }
            }

            # Empty list should not throw
            { Get-SEPMEventInfo } | Should -Not -Throw
        }
    }
}
