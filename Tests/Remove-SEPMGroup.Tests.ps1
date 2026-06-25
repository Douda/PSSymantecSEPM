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

    Context 'basic ops' {
        BeforeAll {
            $script:fakeSession = Set-TestMocks -SkipCert -Transport {
                return @{ deleted = $true }
            }

            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM {
                return @(
                    [PSCustomObject]@{ id = 'target-id'; name = 'TestGroup'; fullPathName = 'My Company\TestGroup' },
                    [PSCustomObject]@{ id = 'mc-id'; name = 'My Company'; fullPathName = 'My Company' }
                )
            }
        }

        It 'calls DELETE on the group ID' {
            Remove-SEPMGroup -GroupName 'TestGroup' -ParentGroup 'My Company'

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'DELETE' -and
                $Uri -eq "$($script:fakeSession.BaseURLv1)/groups/target-id"
            }
        }

        It 'suppresses output when -PassThru is not specified' {
            $result = Remove-SEPMGroup -GroupName 'TestGroup' -ParentGroup 'My Company'

            $result | Should -BeNullOrEmpty
        }

        It 'emits response when -PassThru is specified' {
            $result = Remove-SEPMGroup -GroupName 'TestGroup' -ParentGroup 'My Company' -PassThru

            $result | Should -Not -BeNullOrEmpty
            $result.deleted | Should -BeTrue
        }
    }

    Context 'Group not found' {
        BeforeAll {
            $script:fakeSession = Set-TestMocks -SkipCert -Transport {
                return $null
            }

            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM {
                return @(
                    [PSCustomObject]@{ id = 'mc-id'; name = 'My Company'; fullPathName = 'My Company' }
                )
            }

            $script:errors = @()
        }

        It 'writes an error when group does not exist' {
            Remove-SEPMGroup -GroupName 'NonExistent' -ParentGroup 'My Company' -ErrorVariable script:errors

            $script:errors.Count | Should -BeGreaterThan 0
        }
    }
}
