[CmdletBinding()]
param()

Describe 'New-SEPMGroup' {
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
                    [PSCustomObject]@{ id = 'parent-789'; name = 'Workstations'; fullPathName = 'My Company\Workstations' },
                    [PSCustomObject]@{ id = 'mc-id'; name = 'My Company'; fullPathName = 'My Company' }
                )
            }

            $script:apiCalls = @()
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                $script:apiCalls += [PSCustomObject]@{
                    Method      = $Method
                    Uri         = $Uri
                    Body        = $Body
                    ContentType = $ContentType
                }
                return @{ id = 'new-group-001'; name = 'Win7' }
            }
        }

        It 'sends POST with group data in JSON body' {
            New-SEPMGroup -GroupName 'Win7' -ParentGroup 'My Company\Workstations'

            $script:apiCalls.Count | Should -Be 1
            $script:apiCalls[0].Method      | Should -Be 'POST'
            $script:apiCalls[0].Uri         | Should -Be "$($fakeSession.BaseURLv1)/groups/parent-789"
            $script:apiCalls[0].ContentType | Should -Be 'application/json'

            $body = $script:apiCalls[0].Body | ConvertFrom-Json
            $body.name      | Should -Be 'Win7'
            $body.PSObject.Properties.Name | Should -Not -Contain 'inherits'
            $body.PSObject.Properties.Name | Should -Not -Contain 'description'
        }

        It 'sends EnabledInheritance flag in body' {
            New-SEPMGroup -GroupName 'Win10' -ParentGroup 'My Company\Workstations' -EnabledInheritance

            $script:apiCalls.Count | Should -Be 2
            $body = $script:apiCalls[1].Body | ConvertFrom-Json
            $body.inherits | Should -BeTrue
            $body.name     | Should -Be 'Win10'
        }

        It 'sends description in body' {
            New-SEPMGroup -GroupName 'Servers' -ParentGroup 'My Company' -Description 'Server group'

            $script:apiCalls.Count | Should -Be 3
            $body = $script:apiCalls[2].Body | ConvertFrom-Json
            $body.description | Should -Be 'Server group'
            $body.name        | Should -Be 'Servers'
        }

        It 'returns the Invoke-SepmApi response' {
            $result = New-SEPMGroup -GroupName 'LinuxServers' -ParentGroup 'My Company\Workstations'

            $result.id   | Should -Be 'new-group-001'
            $result.name | Should -Be 'Win7'
        }
    }

    Context 'error handling' {
        BeforeAll {
            $fakeSession = New-TestSession
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }

            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM { }
        }

        It 'writes error when parent group not found' {
            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM {
                return @([PSCustomObject]@{ id = 'mc-id'; name = 'My Company'; fullPathName = 'My Company' })
            }

            $script:errors = @()
            New-SEPMGroup -GroupName 'BadChild' -ParentGroup 'My Company\NonExistent' -ErrorVariable script:errors

            $script:errors.Count | Should -BeGreaterThan 0
            $script:errors[0].Exception.Message | Should -Match 'group'
        }
    }
}
