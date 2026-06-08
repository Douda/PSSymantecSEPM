[CmdletBinding()]
param()

Describe 'Get-SEPMPolicySnapshot' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment

        InModuleScope PSSymantecSEPM {
            $script:configurationFilePath = Join-Path -Path 'TestDrive:' -ChildPath 'config.json'
            $script:credentialsFilePath   = Join-Path -Path 'TestDrive:' -ChildPath 'creds.xml'
            $script:accessTokenFilePath   = Join-Path -Path 'TestDrive:' -ChildPath 'token.xml'
        }
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Tracer bullet' {
        BeforeAll {
            Mock Get-SEPMFirewallPolicy -ModuleName PSSymantecSEPM { return @() }
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM { return @() }
            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM { return @() }
            Mock Get-SEPMLocation -ModuleName PSSymantecSEPM { return @() }
        }

        It 'returns a SEPM.PolicySnapshot with FetchedAt timestamp' {
            $result = Get-SEPMPolicySnapshot -PolicyType fw

            $result.PSObject.TypeNames[0] | Should -Be 'SEPM.PolicySnapshot'
            $result.FetchedAt | Should -BeOfType [DateTime]
        }
    }

    Context 'FW snapshot' {
        BeforeAll {
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM { return @() }
            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM { return @() }
            Mock Get-SEPMLocation -ModuleName PSSymantecSEPM { return @() }
        }

        It 'populates FW.Policies with output from Get-SEPMFirewallPolicy -All' {
            $fwPolicies = @(
                New-DummyFirewallPolicy -PolicyName 'FW Policy 1'
                New-DummyFirewallPolicy -PolicyName 'FW Policy 2'
            )
            Mock Get-SEPMFirewallPolicy -ModuleName PSSymantecSEPM { return $fwPolicies }

            $result = Get-SEPMPolicySnapshot -PolicyType fw

            $result.FW.Policies | Should -Not -BeNullOrEmpty
            $result.FW.Policies.Count | Should -Be 2
            $result.FW.Policies[0].name | Should -Be 'FW Policy 1'
            $result.FW.Policies[0].PSObject.TypeNames[0] | Should -Be 'SEPM.FirewallPolicy'
        }

        It 'populates FW.Summary with output from Get-SEPMPoliciesSummary -PolicyType fw' {
            Mock Get-SEPMFirewallPolicy -ModuleName PSSymantecSEPM { return @() }
            $fwSummaries = @(
                New-DummyPolicySummary -PolicyName 'FW Summary 1' -PolicyType 'fw'
                New-DummyPolicySummary -PolicyName 'FW Summary 2' -PolicyType 'fw'
            )
            $fwSummaries | ForEach-Object { $_.PSObject.TypeNames.Insert(0, 'SEPM.PolicySummary') }
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM { return $fwSummaries }

            $result = Get-SEPMPolicySnapshot -PolicyType fw

            $result.FW.Summary | Should -Not -BeNullOrEmpty
            $result.FW.Summary.Count | Should -Be 2
            $result.FW.Summary[0].name | Should -Be 'FW Summary 1'
            $result.FW.Summary[0].PSObject.TypeNames[0] | Should -Be 'SEPM.PolicySummary'
        }
    }

    Context 'LocationMap' {
        BeforeAll {
            Mock Get-SEPMFirewallPolicy -ModuleName PSSymantecSEPM { return @() }
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM { return @() }
        }

        It 'builds a hashtable mapping locationId to locationName' {
            $loc1 = New-DummyLocation -LocationName 'Default' -LocationID 'loc-id-001' -GroupID 'group-001' -GroupName 'My Company' -GroupFullPathName 'My Company'
            $loc2 = New-DummyLocation -LocationName 'VPN'     -LocationID 'loc-id-002' -GroupID 'group-001' -GroupName 'My Company' -GroupFullPathName 'My Company'

            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM {
                return @([PSCustomObject]@{ id = 'group-001'; name = 'My Company'; fullPathName = 'My Company' })
            }
            Mock Get-SEPMLocation -ModuleName PSSymantecSEPM { return @($loc1, $loc2) }

            $result = Get-SEPMPolicySnapshot -PolicyType fw

            $result.LocationMap | Should -Not -BeNullOrEmpty
            $result.LocationMap['loc-id-001'] | Should -Be 'Default'
            $result.LocationMap['loc-id-002'] | Should -Be 'VPN'
        }
    }

    Context 'DelayMs' {
        BeforeAll {
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM { return @() }
            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM { return @() }
            Mock Get-SEPMLocation -ModuleName PSSymantecSEPM { return @() }
        }

        It 'forwards default DelayMs (200) to Get-SEPMFirewallPolicy -All' {
            Mock Get-SEPMFirewallPolicy -ModuleName PSSymantecSEPM { return @() }

            Get-SEPMPolicySnapshot -PolicyType fw | Out-Null

            Should -Invoke Get-SEPMFirewallPolicy -ModuleName PSSymantecSEPM -Exactly 1 -Scope It -ParameterFilter {
                $All.IsPresent -and $DelayMs -eq 200
            }
        }

        It 'forwards custom DelayMs to Get-SEPMFirewallPolicy -All' {
            Mock Get-SEPMFirewallPolicy -ModuleName PSSymantecSEPM { return @() }

            Get-SEPMPolicySnapshot -PolicyType fw -DelayMs 500 | Out-Null

            Should -Invoke Get-SEPMFirewallPolicy -ModuleName PSSymantecSEPM -Exactly 1 -Scope It -ParameterFilter {
                $All.IsPresent -and $DelayMs -eq 500
            }
        }
    }

    Context 'Multi-policy-type' {
        BeforeAll {
            Mock Get-SEPMFirewallPolicy -ModuleName PSSymantecSEPM { return @() }
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM { return @() }
            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM { return @() }
            Mock Get-SEPMLocation -ModuleName PSSymantecSEPM { return @() }
        }

        It 'creates FW and IPS properties when both types requested' {
            $result = Get-SEPMPolicySnapshot -PolicyType fw, ips

            $result.PSObject.Properties.Name | Should -Contain 'FW'
            $result.PSObject.Properties.Name | Should -Contain 'IPS'
        }

        It 'IPS property has Policies and Summary sub-properties' {
            $result = Get-SEPMPolicySnapshot -PolicyType fw, ips

            $result.IPS | Should -Not -BeNullOrEmpty
            $result.IPS.PSObject.Properties.Name | Should -Contain 'Policies'
            $result.IPS.PSObject.Properties.Name | Should -Contain 'Summary'
            $result.IPS.Policies.Count | Should -Be 0
            $result.IPS.Summary.Count  | Should -Be 0
        }

        It 'omits FW property when not requested' {
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM { return @() }
            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM { return @() }
            Mock Get-SEPMLocation -ModuleName PSSymantecSEPM { return @() }

            $result = Get-SEPMPolicySnapshot -PolicyType ips

            $result.PSObject.Properties.Name | Should -Not -Contain 'FW'
            $result.PSObject.Properties.Name | Should -Contain 'IPS'
        }
    }

    Context 'Clixml round-trip' {
        BeforeAll {
            $loc = New-DummyLocation -LocationName 'Default' -LocationID 'loc-001' -GroupID 'group-001' -GroupName 'My Company' -GroupFullPathName 'My Company'
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM { return @() }
            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM {
                return @([PSCustomObject]@{ id = 'group-001'; name = 'My Company'; fullPathName = 'My Company' })
            }
            Mock Get-SEPMLocation -ModuleName PSSymantecSEPM { return @($loc) }
            Mock Get-SEPMFirewallPolicy -ModuleName PSSymantecSEPM { return @() }
        }

        It 'survives Export-Clixml and Import-Clixml round-trip' {
            $original = Get-SEPMPolicySnapshot -PolicyType fw
            $xmlPath = Join-Path -Path 'TestDrive:' -ChildPath 'snapshot.xml'

            $original | Export-Clixml -Path $xmlPath
            $restored = Import-Clixml -Path $xmlPath

            $restored.PSObject.TypeNames[0] | Should -Be 'Deserialized.SEPM.PolicySnapshot'
            $restored.FetchedAt | Should -BeOfType [DateTime]
            $restored.FW | Should -Not -BeNullOrEmpty
            $restored.LocationMap | Should -Not -BeNullOrEmpty
            $restored.LocationMap['loc-001'] | Should -Be 'Default'
        }
    }
}
