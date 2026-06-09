[CmdletBinding()]
param()

Describe 'Get-SEPMReplicationStatus' {
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

        It 'returns replication status with expected fields' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{
                    replicationStatus = @(
                        @{
                            siteName                    = 'Site WIN-P093KPK2K7Q'
                            siteLocation                = 'N/A'
                            id                          = '4D0C6496AC1E00022D66B9F79AA03701'
                            replicationPartnerStatusList = @()
                        }
                    )
                }
            }

            $result = Get-SEPMReplicationStatus
            $result.Count      | Should -Be 1
            $result[0].siteName     | Should -Be 'Site WIN-P093KPK2K7Q'
            $result[0].siteLocation | Should -Be 'N/A'
        }

        It 'adds SEPM.ReplicationStatus type name' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{
                    replicationStatus = @(
                        @{
                            siteName                    = 'Site Test'
                            siteLocation                = 'Test'
                            id                          = 'ID001'
                            replicationPartnerStatusList = @()
                        }
                    )
                }
            }

            $result = Get-SEPMReplicationStatus
            $result[0].PSObject.TypeNames[0] | Should -Be 'SEPM.ReplicationStatus'
        }

        It 'calls the correct API endpoint' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{ replicationStatus = @() }
            }

            Get-SEPMReplicationStatus | Out-Null
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'GET' -and $Uri -match '/replication/status$'
            }
        }
    }
}
