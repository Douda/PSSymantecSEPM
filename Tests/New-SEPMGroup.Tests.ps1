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
            $script:fakeSession = Set-TestMocks -Transport {
                return @{ id = 'new-group-001'; name = 'Win7' }
            }

            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM {
                return @(
                    [PSCustomObject]@{ id = 'parent-789'; name = 'Workstations'; fullPathName = 'My Company\Workstations' },
                    [PSCustomObject]@{ id = 'mc-id'; name = 'My Company'; fullPathName = 'My Company' }
                )
            }
        }

        It 'sends POST with group data in JSON body' {
            New-SEPMGroup -GroupName 'Win7' -ParentGroup 'My Company\Workstations'

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and
                $Uri -eq "$($script:fakeSession.BaseURLv1)/groups/parent-789" -and
                $ContentType -eq 'application/json' -and
                $Body -match '"name":\s*"Win7"' -and
                $Body -notmatch 'inherits' -and
                $Body -notmatch 'description'
            }
        }

        It 'sends EnabledInheritance flag in body' {
            New-SEPMGroup -GroupName 'Win10' -ParentGroup 'My Company\Workstations' -EnabledInheritance

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and
                $Body -match '"name":\s*"Win10"' -and
                $Body -match '"inherits":\s*true'
            }
        }

        It 'sends description in body' {
            New-SEPMGroup -GroupName 'Servers' -ParentGroup 'My Company' -Description 'Server group'

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and
                $Body -match '"name":\s*"Servers"' -and
                $Body -match '"description":\s*"Server group"'
            }
        }

        It 'returns the Invoke-SepmApi response' {
            $result = New-SEPMGroup -GroupName 'LinuxServers' -ParentGroup 'My Company\Workstations' -PassThru

            $result.id   | Should -Be 'new-group-001'
            $result.name | Should -Be 'Win7'
        }
    }

    Context 'PassThru behavior' {
        BeforeAll {
            $script:fakeSession = Set-TestMocks -Transport {
                return @{ id = 'new-group-001'; name = 'Win7' }
            }

            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM {
                return @([PSCustomObject]@{ id = 'parent-789'; name = 'Workstations'; fullPathName = 'My Company\Workstations' })
            }
        }

        It 'suppresses output when -PassThru is not specified' {
            $result = New-SEPMGroup -GroupName 'QuietGroup' -ParentGroup 'My Company\Workstations'

            $result | Should -BeNullOrEmpty
        }

        It 'emits response when -PassThru is specified' {
            $result = New-SEPMGroup -GroupName 'EmitGroup' -ParentGroup 'My Company\Workstations' -PassThru

            $result | Should -Not -BeNullOrEmpty
            $result.id | Should -Be 'new-group-001'
        }
    }

    Context 'error handling' {
        BeforeAll {
            $script:fakeSession = Set-TestMocks -Transport {
                return $null
            }
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
