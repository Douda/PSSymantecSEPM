[CmdletBinding()]
param()

Describe 'Remove-SEPMGroup' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Deletion' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }

            # Mock Get-SEPMGroups to return the target group
            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM {
                return @(
                    [PSCustomObject]@{ id = 'target-id'; name = 'TestGroup'; fullPathName = 'My Company\TestGroup' },
                    [PSCustomObject]@{ id = 'mc-id'; name = 'My Company'; fullPathName = 'My Company' }
                )
            }

            $script:apiCalls = @()
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                $script:apiCalls += [PSCustomObject]@{
                    Method = $Method
                    Uri    = $Uri
                }
            }
        }

        It 'calls DELETE on the group ID' {
            Remove-SEPMGroup -GroupName 'TestGroup' -ParentGroup 'My Company'

            $script:apiCalls.Count | Should -Be 1
            $script:apiCalls[0].Method | Should -Be 'DELETE'
            $script:apiCalls[0].Uri    | Should -Be "$($fakeSession.BaseURLv1)/groups/target-id"
        }
    }

    Context 'Group not found' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }

            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM {
                return @(
                    [PSCustomObject]@{ id = 'mc-id'; name = 'My Company'; fullPathName = 'My Company' }
                )
            }

            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM { }

            $script:errors = @()
        }

        It 'writes an error when group does not exist' {
            Remove-SEPMGroup -GroupName 'NonExistent' -ParentGroup 'My Company' -ErrorVariable script:errors

            $script:errors.Count | Should -BeGreaterThan 0
        }
    }
}
