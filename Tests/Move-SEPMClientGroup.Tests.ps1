[CmdletBinding()]
param()

Describe 'Move-SEPMClientGroup' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'happy path' {
        BeforeAll {
            $script:fakeSession = Set-TestMocks -Transport {
                return @{ responseCode = 0; responseMessage = 'Success' }
            }

            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM {
                return @(
                    [PSCustomObject]@{ id = 'group-123'; name = 'Workstations'; fullPathName = 'My Company\Workstations' },
                    [PSCustomObject]@{ id = 'mc-id'; name = 'My Company'; fullPathName = 'My Company' }
                )
            }

            Mock Get-SEPMComputers -ModuleName PSSymantecSEPM {
                param($ComputerName)
                return [PSCustomObject]@{ computerName = $ComputerName; hardwareKey = 'HK-ABC123' }
            }
        }

        It 'sends PATCH to /computers with hardwareKey and group ID in body' {
            Move-SEPMClientGroup -ComputerName 'MyComputer' -GroupName 'My Company\Workstations'

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'PATCH' -and
                $Uri -eq "$($script:fakeSession.BaseURLv1)/computers" -and
                $ContentType -eq 'application/json' -and
                $Body -match 'HK-ABC123' -and
                $Body -match 'group-123'
            }
        }

        It 'returns SEPM.MoveClientGroupResponse type' {
            $result = Move-SEPMClientGroup -ComputerName 'MyComputer' -GroupName 'My Company\Workstations'

            $result.PSObject.TypeNames[0] | Should -Be 'SEPM.MoveClientGroupResponse'
            $result.computerName          | Should -Be 'MyComputer'
            $result.computerHardwareKey   | Should -Be 'HK-ABC123'
            $result.targetGroup           | Should -Be 'My Company\Workstations'
            $result.responseCode          | Should -Be 0
            $result.responseMessage       | Should -Be 'Success'
        }
    }

    Context 'error handling' {
        BeforeAll {
            $script:fakeSession = Set-TestMocks -Transport {
                return @{ responseCode = 0; responseMessage = 'Success' }
            }
        }

        It 'writes error when computer hardwareKey not found' {
            Mock Get-SEPMComputers -ModuleName PSSymantecSEPM { return $null }
            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM {
                return @([PSCustomObject]@{ id = 'g1'; name = 'W'; fullPathName = 'My Company\Workstations' })
            }

            $script:errors = @()
            Move-SEPMClientGroup -ComputerName 'NonExistent' -GroupName 'My Company\Workstations' -ErrorVariable script:errors

            $script:errors.Count | Should -BeGreaterThan 0
            $script:errors[0].Exception.Message | Should -Match 'HardwareKey'
        }

        It 'writes error when target group not found' {
            Mock Get-SEPMComputers -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ computerName = 'MyComputer'; hardwareKey = 'HK-XYZ' }
            }
            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM {
                return @([PSCustomObject]@{ id = 'mc-id'; name = 'My Company'; fullPathName = 'My Company' })
            }

            $script:errors = @()
            Move-SEPMClientGroup -ComputerName 'MyComputer' -GroupName 'My Company\BadGroup' -ErrorAction SilentlyContinue -ErrorVariable script:errors

            @($script:errors).Count | Should -BeGreaterThan 0
            # PS 5.1 + mocks + -ErrorAction SilentlyContinue produces 2 errors:
            # [0] StopUpstreamCommandsException (Exception=$null), [1] the real error.
            # Use the last error in the array for the actual message.
            $realError = $script:errors[-1]
            $actualMessage = if ($realError.Exception.InnerException) {
                $realError.Exception.InnerException.Message
            } else {
                $realError.Exception.Message
            }
            $actualMessage | Should -Match 'Group'
        }
    }

    Context 'pipeline input' {
        BeforeAll {
            $script:fakeSession = Set-TestMocks -Transport {
                return @{ responseCode = 0; responseMessage = 'Success' }
            }

            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM {
                return @(
                    [PSCustomObject]@{ id = 'group-456'; name = 'Servers'; fullPathName = 'My Company\Servers' }
                )
            }

            Mock Get-SEPMComputers -ModuleName PSSymantecSEPM {
                param($ComputerName)
                return [PSCustomObject]@{ computerName = $ComputerName; hardwareKey = "HK-$ComputerName" }
            }
        }

        It 'processes multiple computers via 3 PATCH calls with correct hardware keys and target group' {
            'PC1', 'PC2', 'PC3' | Move-SEPMClientGroup -GroupName 'My Company\Servers'

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 3 -Exactly -ParameterFilter {
                $Method -eq 'PATCH' -and
                $Uri -eq "$($script:fakeSession.BaseURLv1)/computers"
            }

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Body -match 'HK-PC1' -and $Body -match 'group-456'
            }
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Body -match 'HK-PC2' -and $Body -match 'group-456'
            }
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Body -match 'HK-PC3' -and $Body -match 'group-456'
            }
        }
    }
}
