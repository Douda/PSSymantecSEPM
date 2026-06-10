[CmdletBinding()]
param()

Describe 'Move-SEPClientGroup' {
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

            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM {
                return @(
                    [PSCustomObject]@{ id = 'group-123'; name = 'Workstations'; fullPathName = 'My Company\Workstations' },
                    [PSCustomObject]@{ id = 'mc-id'; name = 'My Company'; fullPathName = 'My Company' }
                )
            }

            Mock Get-SEPComputers -ModuleName PSSymantecSEPM {
                param($ComputerName)
                return [PSCustomObject]@{ computerName = $ComputerName; hardwareKey = 'HK-ABC123' }
            }

            $script:apiCalls = @()
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                $script:apiCalls += [PSCustomObject]@{
                    Method      = $Method
                    Uri         = $Uri
                    Body        = $Body
                    ContentType = $ContentType
                }
                return @{ responseCode = 0; responseMessage = 'Success' }
            }
        }

        It 'sends PATCH to /computers with hardwareKey and group ID in body' {
            Move-SEPClientGroup -ComputerName 'MyComputer' -GroupName 'My Company\Workstations'

            $script:apiCalls.Count | Should -Be 1
            $script:apiCalls[0].Method | Should -Be 'PATCH'
            $script:apiCalls[0].Uri    | Should -Be "$($fakeSession.BaseURLv1)/computers"
            $script:apiCalls[0].ContentType | Should -Be 'application/json'

            $body = $script:apiCalls[0].Body | ConvertFrom-Json
            $body[0].hardwareKey    | Should -Be 'HK-ABC123'
            $body[0].group.id       | Should -Be 'group-123'
        }

        It 'returns SEPM.MoveClientGroupResponse type' {
            $result = Move-SEPClientGroup -ComputerName 'MyComputer' -GroupName 'My Company\Workstations'

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
            $fakeSession = New-TestSession
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }

            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM { return @{ responseCode = 0; responseMessage = 'Success' } }
        }

        It 'writes error when computer hardwareKey not found' {
            Mock Get-SEPComputers -ModuleName PSSymantecSEPM { return $null }
            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM {
                return @([PSCustomObject]@{ id = 'g1'; name = 'W'; fullPathName = 'My Company\Workstations' })
            }

            $script:errors = @()
            Move-SEPClientGroup -ComputerName 'NonExistent' -GroupName 'My Company\Workstations' -ErrorVariable script:errors

            $script:errors.Count | Should -BeGreaterThan 0
            $script:errors[0].Exception.Message | Should -Match 'HardwareKey'
        }

        It 'writes error when target group not found' {
            Mock Get-SEPComputers -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ computerName = 'MyComputer'; hardwareKey = 'HK-XYZ' }
            }
            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM {
                return @([PSCustomObject]@{ id = 'mc-id'; name = 'My Company'; fullPathName = 'My Company' })
            }

            $script:errors = @()
            Move-SEPClientGroup -ComputerName 'MyComputer' -GroupName 'My Company\BadGroup' -ErrorAction SilentlyContinue -ErrorVariable script:errors

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
            $fakeSession = New-TestSession
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }

            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM {
                return @([PSCustomObject]@{ id = 'group-456'; name = 'Servers'; fullPathName = 'My Company\Servers' })
            }

            Mock Get-SEPComputers -ModuleName PSSymantecSEPM {
                param($ComputerName)
                return [PSCustomObject]@{ computerName = $ComputerName; hardwareKey = "HK-$ComputerName" }
            }

            $script:apiCalls = @()
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                $script:apiCalls += [PSCustomObject]@{
                    Method = $Method
                    Uri    = $Uri
                    Body   = $Body
                }
                return @{ responseCode = 0; responseMessage = 'Success' }
            }
        }

        It 'processes multiple computers via pipeline' {
            'PC1', 'PC2', 'PC3' | Move-SEPClientGroup -GroupName 'My Company\Servers'

            $script:apiCalls.Count | Should -Be 3
            $script:apiCalls[0].Uri    | Should -Be "$($fakeSession.BaseURLv1)/computers"
            $script:apiCalls[0].Method | Should -Be 'PATCH'

            # Each call should target a different computer
            $body0 = $script:apiCalls[0].Body | ConvertFrom-Json
            $body1 = $script:apiCalls[1].Body | ConvertFrom-Json
            $body2 = $script:apiCalls[2].Body | ConvertFrom-Json

            $body0[0].hardwareKey | Should -Be 'HK-PC1'
            $body1[0].hardwareKey | Should -Be 'HK-PC2'
            $body2[0].hardwareKey | Should -Be 'HK-PC3'

            # All target the same group
            $body0[0].group.id | Should -Be 'group-456'
            $body1[0].group.id | Should -Be 'group-456'
            $body2[0].group.id | Should -Be 'group-456'
        }
    }
}
