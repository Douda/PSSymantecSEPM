[CmdletBinding()]
param()

Describe 'Get-SEPMPolicySnapshot' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'PolicyType fw' {
        BeforeAll {
            $script:fakeSession = New-TestSession -SkipCert

            $script:dummyPolicies = @(
                New-DummyFirewallPolicy -PolicyName 'FW Policy 1'
                New-DummyFirewallPolicy -PolicyName 'FW Policy 2'
                New-DummyFirewallPolicy -PolicyName 'FW Policy 3'
            )

            $script:dummySummaries = @(
                New-DummyPolicySummary -PolicyName 'FW Policy 1' -PolicyType 'fw'
                New-DummyPolicySummary -PolicyName 'FW Policy 2' -PolicyType 'fw'
                New-DummyPolicySummary -PolicyName 'FW Policy 3' -PolicyType 'fw'
            )

            $script:dummyGroups = @(
                [PSCustomObject]@{ id = 'group-1'; name = 'My Company'; fullPathName = 'My Company' }
                [PSCustomObject]@{ id = 'group-2'; name = 'Workstations'; fullPathName = 'My Company\Workstations' }
            )

            # Location strings returned by Invoke-SepmApi for each group's /locations endpoint
            $script:locationResponses = @{
                'group-1' = @('Default: /sepm/api/v1/groups/group-1/locations/loc-default')
                'group-2' = @('Office: /sepm/api/v1/groups/group-2/locations/loc-office', 'Remote: /sepm/api/v1/groups/group-2/locations/loc-remote')
            }
        }

        It 'returns a SEPM.PolicySnapshot PSObject with correct nested structure' {
            Mock Get-SEPMFirewallPolicy -ModuleName PSSymantecSEPM -ParameterFilter { $All } {
                return $script:dummyPolicies
            }
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM -ParameterFilter { $PolicyType -eq 'fw' } {
                return $script:dummySummaries
            }
            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM {
                return $script:dummyGroups
            }
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM {
                return $script:fakeSession
            }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter { $Uri -match '/locations' } {
                foreach ($gid in $script:locationResponses.Keys) {
                    if ($Uri -match $gid) { return $script:locationResponses[$gid] }
                }
                return @()
            }

            $result = Get-SEPMPolicySnapshot -PolicyType fw

            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.TypeNames[0] | Should -Be 'SEPM.PolicySnapshot'

            # FW nested structure
            $result.FW | Should -Not -BeNullOrEmpty
            $result.FW | Should -BeOfType [PSCustomObject]
            $result.FW.Policies | Should -Not -BeNullOrEmpty
            $result.FW.Summary | Should -Not -BeNullOrEmpty

            # LocationMap
            $result.LocationMap | Should -Not -BeNullOrEmpty
            $result.LocationMap | Should -BeOfType [hashtable]

            # FetchedAt
            $result.FetchedAt | Should -Not -BeNullOrEmpty
            $result.FetchedAt | Should -BeOfType [DateTime]
        }

        It 'survives Export-Clixml round-trip with Deserialized PSTypeName' {
            Mock Get-SEPMFirewallPolicy -ModuleName PSSymantecSEPM -ParameterFilter { $All } {
                return $script:dummyPolicies
            }
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM -ParameterFilter { $PolicyType -eq 'fw' } {
                return $script:dummySummaries
            }
            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM {
                return $script:dummyGroups
            }
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM {
                return $script:fakeSession
            }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter { $Uri -match '/locations' } {
                foreach ($gid in $script:locationResponses.Keys) {
                    if ($Uri -match $gid) { return $script:locationResponses[$gid] }
                }
                return @()
            }

            $original = Get-SEPMPolicySnapshot -PolicyType fw
            $tmpPath = Join-Path -Path 'TestDrive:' -ChildPath 'snapshot.xml'
            $original | Export-Clixml -Path $tmpPath
            $reimported = Import-Clixml -Path $tmpPath

            $reimported | Should -Not -BeNullOrEmpty
            $reimported.PSObject.TypeNames[0] | Should -Be 'Deserialized.SEPM.PolicySnapshot'
            $reimported.FW.Policies.Count | Should -Be 3
            $reimported.FW.Summary.Count | Should -Be 3
            $reimported.FetchedAt | Should -BeOfType [DateTime]
        }

        It 'forwards -DelayMs to Get-SEPMFirewallPolicy -All' {
            Mock Get-SEPMFirewallPolicy -ModuleName PSSymantecSEPM -ParameterFilter { $All -and $DelayMs -eq 500 } {
                return $script:dummyPolicies
            }
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM -ParameterFilter { $PolicyType -eq 'fw' } {
                return $script:dummySummaries
            }
            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM {
                return $script:dummyGroups
            }
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM {
                return $script:fakeSession
            }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter { $Uri -match '/locations' } {
                foreach ($gid in $script:locationResponses.Keys) {
                    if ($Uri -match $gid) { return $script:locationResponses[$gid] }
                }
                return @()
            }

            $result = Get-SEPMPolicySnapshot -PolicyType fw -DelayMs 500

            $result | Should -Not -BeNullOrEmpty
            Should -Invoke Get-SEPMFirewallPolicy -ModuleName PSSymantecSEPM -Exactly 1 -Scope It -ParameterFilter { $All -and $DelayMs -eq 500 }
        }

        It 'FetchedAt is set at snapshot creation time within a small tolerance' {
            Mock Get-SEPMFirewallPolicy -ModuleName PSSymantecSEPM -ParameterFilter { $All } {
                return $script:dummyPolicies
            }
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM -ParameterFilter { $PolicyType -eq 'fw' } {
                return $script:dummySummaries
            }
            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM {
                return $script:dummyGroups
            }
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM {
                return $script:fakeSession
            }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter { $Uri -match '/locations' } {
                foreach ($gid in $script:locationResponses.Keys) {
                    if ($Uri -match $gid) { return $script:locationResponses[$gid] }
                }
                return @()
            }

            $before = Get-Date
            $result = Get-SEPMPolicySnapshot -PolicyType fw
            $after = Get-Date

            $result.FetchedAt | Should -BeGreaterOrEqual $before
            $result.FetchedAt | Should -BeLessOrEqual $after
        }

        It 'LocationMap resolves every location ID to a human-readable name' {
            Mock Get-SEPMFirewallPolicy -ModuleName PSSymantecSEPM -ParameterFilter { $All } {
                return $script:dummyPolicies
            }
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM -ParameterFilter { $PolicyType -eq 'fw' } {
                return $script:dummySummaries
            }
            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM {
                return $script:dummyGroups
            }
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM {
                return $script:fakeSession
            }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter { $Uri -match '/locations' } {
                foreach ($gid in $script:locationResponses.Keys) {
                    if ($Uri -match $gid) { return $script:locationResponses[$gid] }
                }
                return @()
            }

            $result = Get-SEPMPolicySnapshot -PolicyType fw

            $result.LocationMap.Count | Should -Be 3
            $result.LocationMap['loc-default'] | Should -Be 'Default'
            $result.LocationMap['loc-office'] | Should -Be 'Office'
            $result.LocationMap['loc-remote'] | Should -Be 'Remote'
        }

        It 'FW.Summary contains all FW policy summary entries' {
            Mock Get-SEPMFirewallPolicy -ModuleName PSSymantecSEPM -ParameterFilter { $All } {
                return $script:dummyPolicies
            }
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM -ParameterFilter { $PolicyType -eq 'fw' } {
                return $script:dummySummaries
            }
            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM {
                return $script:dummyGroups
            }
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM {
                return $script:fakeSession
            }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter { $Uri -match '/locations' } {
                foreach ($gid in $script:locationResponses.Keys) {
                    if ($Uri -match $gid) { return $script:locationResponses[$gid] }
                }
                return @()
            }

            $result = Get-SEPMPolicySnapshot -PolicyType fw

            $result.FW.Summary.Count | Should -Be 3
            $result.FW.Summary[0].name | Should -Be 'FW Policy 1'
            $result.FW.Summary[1].name | Should -Be 'FW Policy 2'
            $result.FW.Summary[2].name | Should -Be 'FW Policy 3'
            # Verify policy type from summary
            $result.FW.Summary[0].policytype | Should -Be 'fw'
        }

        It 'FW.Policies contains all full FW policy objects with PSTypeName preserved' {
            Mock Get-SEPMFirewallPolicy -ModuleName PSSymantecSEPM -ParameterFilter { $All } {
                return $script:dummyPolicies
            }
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM -ParameterFilter { $PolicyType -eq 'fw' } {
                return $script:dummySummaries
            }
            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM {
                return $script:dummyGroups
            }
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM {
                return $script:fakeSession
            }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter { $Uri -match '/locations' } {
                foreach ($gid in $script:locationResponses.Keys) {
                    if ($Uri -match $gid) { return $script:locationResponses[$gid] }
                }
                return @()
            }

            $result = Get-SEPMPolicySnapshot -PolicyType fw

            $result.FW.Policies.Count | Should -Be 3
            $result.FW.Policies[0].name | Should -Be 'FW Policy 1'
            $result.FW.Policies[1].name | Should -Be 'FW Policy 2'
            $result.FW.Policies[2].name | Should -Be 'FW Policy 3'
            # PSTypeName preserved from source cmdlet
            $result.FW.Policies[0].PSObject.TypeNames[0] | Should -Be 'SEPM.FirewallPolicy'
        }
    }
}
