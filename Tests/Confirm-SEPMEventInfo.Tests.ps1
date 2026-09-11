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
            $script:apiCalls = @()
            $script:fakeSession = Set-TestMocks -Transport {
                param($Session, $Method, $Uri, $Body, $ContentType)
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
            $script:apiCalls[0].Uri    | Should -Be "$($script:fakeSession.BaseURLv1)/events/acknowledge/EVT-CRITICAL-001"
        }

        It 'returns $true on successful acknowledgement' {
            $result = Confirm-SEPMEventInfo -EventID 'EVT-OK-002'

            $result | Should -BeTrue
        }
    }

    Context 'error handling' {
        BeforeAll {
            $null = Set-TestMocks -Transport { return @{ ack = 'ok' } }
        }

        It 'returns $false when event is not acknowledgeable' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                throw (New-SEPMApiError -Message 'SEPM API POST /sepm/api/v1/events/acknowledge/EVT-NON-ACKABLE failed (HTTP 400): Failed to update the event, summary:Could not find notification' `
                        -Category ([System.Management.Automation.ErrorCategory]::InvalidData) -Target 'https://sepm')
            }

            $result = Confirm-SEPMEventInfo -EventID 'EVT-NON-ACKABLE' -WarningAction SilentlyContinue

            $result | Should -BeFalse
        }

        It 'writes error when event is not acknowledgeable' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                throw (New-SEPMApiError -Message 'SEPM API POST /sepm/api/v1/events/acknowledge/EVT-BAD-TYPE failed (HTTP 400): Failed to update the event' `
                        -Category ([System.Management.Automation.ErrorCategory]::InvalidData) -Target 'https://sepm')
            }

            $captured = & { Confirm-SEPMEventInfo -EventID 'EVT-BAD-TYPE' -WarningAction SilentlyContinue } 2>&1
            $errors = @($captured | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })

            $errors.Count | Should -BeGreaterThan 0
            $errors[0].Exception.Message | Should -Match 'acknowledged'
        }

        It 'returns $false on generic API error' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                throw (New-SEPMApiError -Message 'SEPM API POST /sepm/api/v1/events/acknowledge/EVT-ERR-003 failed (HTTP 500): Internal Server Error' `
                        -Category ([System.Management.Automation.ErrorCategory]::ResourceUnavailable) -Target 'https://sepm')
            }

            $result = Confirm-SEPMEventInfo -EventID 'EVT-ERR-003' -WarningAction SilentlyContinue

            $result | Should -BeFalse
        }

        It 'keeps SEPMs own message in the error it writes' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                throw (New-SEPMApiError -Message 'SEPM API POST /sepm/api/v1/events/acknowledge/EVT-DETAIL failed (HTTP 500): Internal Server Error' `
                        -Category ([System.Management.Automation.ErrorCategory]::ResourceUnavailable) -Target 'https://sepm')
            }

            $captured = & { Confirm-SEPMEventInfo -EventID 'EVT-DETAIL' -WarningAction SilentlyContinue } 2>&1
            $errors = @($captured | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })

            $errors[0].Exception.Message | Should -Match 'Internal Server Error'
        }
    }

    Context 'URI construction' {
        BeforeAll {
            $script:apiCalls = @()
            $script:fakeSession = Set-TestMocks -Transport {
                param($Session, $Method, $Uri, $Body, $ContentType)
                $script:apiCalls += [PSCustomObject]@{
                    Method = $Method
                    Uri    = $Uri
                }
                return @{ ack = 'ok' }
            }
        }

        It 'appends event ID directly to acknowledge URI path' {
            Confirm-SEPMEventInfo -EventID '15B9BDBFAC1E000268F855FB4332BCC6'

            $script:apiCalls[0].Uri | Should -BeExactly "$($script:fakeSession.BaseURLv1)/events/acknowledge/15B9BDBFAC1E000268F855FB4332BCC6"
        }
    }
}
