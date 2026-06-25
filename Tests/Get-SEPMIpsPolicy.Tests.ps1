[CmdletBinding()]
param()

Describe 'Get-SEPMIpsPolicy' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Retrieving an IPS policy with configuration' {
        BeforeAll {
            $null = Set-TestMocks -SkipCert -Transport {
                return @{
                    sources          = $null
                    configuration    = @{
                        blocked_hosts = @(
                            @{ ip = '10.0.0.1'; reason = 'ServiceNow discovery' }
                            @{ ip = '10.0.0.2'; reason = 'Dev server' }
                        )
                        enabled_signatures = @('SIG001', 'SIG002', 'SIG003')
                        custom_rules       = @()
                    }
                    enabled          = $true
                    desc             = 'IPS description field'
                    name             = 'My IPS Policy'
                    lastmodifiedtime = 1693559858824
                }
            }
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM {
                return New-DummyPolicySummary -PolicyName 'My IPS Policy' -PolicyType 'ips'
            }
        }

        It 'returns the IPS policy by name with correct top-level properties' {
            $result = Get-SEPMIpsPolicy -PolicyName 'My IPS Policy'

            $result | Should -Not -BeNullOrEmpty
            $result.name | Should -Be 'My IPS Policy'
            $result.enabled | Should -Be $true
            $result.desc | Should -Be 'IPS description field'
            $result.lastmodifiedtime | Should -Be 1693559858824
        }

        It 'returns the nested configuration with blocked_hosts and signatures' {
            $result = Get-SEPMIpsPolicy -PolicyName 'My IPS Policy'

            $result.configuration | Should -Not -BeNullOrEmpty
            $result.configuration.blocked_hosts | Should -Not -BeNullOrEmpty
            $result.configuration.blocked_hosts.Count | Should -Be 2
            $result.configuration.blocked_hosts[0].ip | Should -Be '10.0.0.1'
            $result.configuration.blocked_hosts[1].reason | Should -Be 'Dev server'
            $result.configuration.enabled_signatures | Should -Not -BeNullOrEmpty
            $result.configuration.enabled_signatures.Count | Should -Be 3
            'SIG002' -in $result.configuration.enabled_signatures | Should -Be $true
        }

        It 'accepts PolicyName from the pipeline by property name' {
            $result = 'My IPS Policy' | Get-SEPMIpsPolicy

            $result | Should -Not -BeNullOrEmpty
            $result.name | Should -Be 'My IPS Policy'
        }
    }

    Context 'IPS policy with empty configuration' {
        BeforeAll {
            $null = Set-TestMocks -SkipCert -Transport {
                return @{
                    sources          = $null
                    configuration    = @{}
                    enabled          = $true
                    desc             = 'Minimal IPS'
                    name             = 'Minimal IPS'
                    lastmodifiedtime = 1693559858824
                }
            }
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM {
                return New-DummyPolicySummary -PolicyName 'Minimal IPS' -PolicyType 'ips'
            }
        }

        It 'handles policies with empty configuration hashtable' {
            $result = Get-SEPMIpsPolicy -PolicyName 'Minimal IPS'

            $result | Should -Not -BeNullOrEmpty
            $result.name | Should -Be 'Minimal IPS'
            $null -eq $result.configuration | Should -Be $false
            $result.configuration.Keys.Count | Should -Be 0
        }
    }

    Context 'Using -PolicyList to skip summary fetch' {
        BeforeAll {
            $null = Set-TestMocks -SkipCert -Transport {
                return @{
                    sources          = $null
                    configuration    = @{ blocked_hosts = @(); enabled_signatures = @() }
                    enabled          = $true
                    desc             = 'Policy from list'
                    name             = 'Policy From List'
                    lastmodifiedtime = 1693559858824
                }
            }

            # Get-SEPMPoliciesSummary should throw if called
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM { throw 'Should not be called' }

            $script:policyList = New-DummyPolicySummary -PolicyName 'Policy From List' -PolicyType 'ips'
        }

        It 'resolves policy from -PolicyList without calling Get-SEPMPoliciesSummary' {
            $result = Get-SEPMIpsPolicy -PolicyName 'Policy From List' -PolicyList $script:policyList

            $result | Should -Not -BeNullOrEmpty
            $result.name | Should -Be 'Policy From List'
            Assert-MockCalled -CommandName Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM -Times 0
        }
    }

    Context 'Error handling' {
        BeforeAll {
            $null = Set-TestMocks -SkipCert -Transport { return @{} }
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM {
                return New-DummyPolicySummary -PolicyName 'Not IPS' -PolicyType 'av'
            }
        }

        It 'throws a terminating error when policy type is not ips' {
            { Get-SEPMIpsPolicy -PolicyName 'Not IPS' } | Should -Throw
        }

        It 'error message mentions IPS policy type mismatch' {
            { Get-SEPMIpsPolicy -PolicyName 'Not IPS' } | Should -Throw -ExpectedMessage '*policy type is not of type IPS*'
        }
    }
}
