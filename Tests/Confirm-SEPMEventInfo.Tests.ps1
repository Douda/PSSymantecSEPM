[CmdletBinding()]
param()

Describe 'Confirm-SEPMEventInfo' {
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

            $script:apiCalls = @()
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                $script:apiCalls += [PSCustomObject]@{
                    Method = $Method
                    Uri    = $Uri
                }
                return @{ ack = 'ok' }
            }
        }

        It 'sends POST to /events/acknowledge with event ID in URI' {
            Confirm-SEPMEventInfo -EventID 'EVT-CRITICAL-001'

            $script:apiCalls.Count | Should -Be 1
            $script:apiCalls[0].Method | Should -Be 'POST'
            $script:apiCalls[0].Uri    | Should -Be "$($fakeSession.BaseURLv1)/events/acknowledge/EVT-CRITICAL-001"
        }

        It 'returns $true on successful acknowledgement' {
            $result = Confirm-SEPMEventInfo -EventID 'EVT-OK-002'

            $result | Should -BeTrue
        }
    }

    Context 'error handling' {
        BeforeAll {
            $fakeSession = New-TestSession
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
        }

        It 'returns $false when event is not acknowledgeable' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return 'errorCode: 4104, Failed to update the event, summary:Could not find notification'
            }

            $result = Confirm-SEPMEventInfo -EventID 'EVT-NON-ACKABLE' -WarningAction SilentlyContinue

            $result | Should -BeFalse
        }

        It 'writes error when event is not acknowledgeable' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return 'errorCode: 4104, Failed to update the event, summary:Could not find notification'
            }

            $script:errors = @()
            Confirm-SEPMEventInfo -EventID 'EVT-BAD-TYPE' -WarningAction SilentlyContinue -ErrorVariable script:errors

            $script:errors.Count | Should -BeGreaterThan 0
            $script:errors[0].Exception.Message | Should -Match 'acknowledged'
        }

        It 'returns $false on generic API error' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return 'errorCode: 999, Some other failure'
            }

            $result = Confirm-SEPMEventInfo -EventID 'EVT-ERR-003' -WarningAction SilentlyContinue

            $result | Should -BeFalse
        }
    }

    Context 'URI construction' {
        BeforeAll {
            $fakeSession = New-TestSession
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }

            $script:apiCalls = @()
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                $script:apiCalls += [PSCustomObject]@{
                    Method = $Method
                    Uri    = $Uri
                }
                return @{ ack = 'ok' }
            }
        }

        It 'appends event ID directly to acknowledge URI path' {
            Confirm-SEPMEventInfo -EventID '15B9BDBFAC1E000268F855FB4332BCC6'

            $script:apiCalls[0].Uri | Should -BeExactly "$($fakeSession.BaseURLv1)/events/acknowledge/15B9BDBFAC1E000268F855FB4332BCC6"
        }
    }
}
