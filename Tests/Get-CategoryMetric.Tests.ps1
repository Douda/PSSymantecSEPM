[CmdletBinding()]
param()

Describe 'Get-CategoryMetric' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Edge cases' {
        It 'returns empty string for null data' {
            InModuleScope PSSymantecSEPM {
                $result = Get-CategoryMetric -Category 'Domains' -Data $null
                $result | Should -Be ''
            }
        }

        It 'returns "error" when failed is true' {
            InModuleScope PSSymantecSEPM {
                $result = Get-CategoryMetric -Category 'Domains' -Data 'some data' -Failed $true
                $result | Should -Be 'error'
            }
        }

        It 'returns empty string for failed with null data' {
            InModuleScope PSSymantecSEPM {
                $result = Get-CategoryMetric -Category 'Computers' -Data $null -Failed $false
                $result | Should -Be ''
            }
        }
    }

    Context 'Category-specific metrics' {
        It 'returns pluralized count for Domains' {
            InModuleScope PSSymantecSEPM {
                $result = Get-CategoryMetric -Category 'Domains' -Data @('domain1', 'domain2', 'domain3')
                $result | Should -Be '3 domains'
            }
        }

        It 'returns singular form for single-item Domains' {
            InModuleScope PSSymantecSEPM {
                $result = Get-CategoryMetric -Category 'Domains' -Data @('domain1')
                $result | Should -Be '1 domain'
            }
        }

        It 'returns count with GUP(s) for GUPs' {
            InModuleScope PSSymantecSEPM {
                $result = Get-CategoryMetric -Category 'GUPs' -Data @('gup1', 'gup2')
                $result | Should -Be '2 GUPs'
            }
        }

        It 'returns count with admin(s) for Admins' {
            InModuleScope PSSymantecSEPM {
                $result = Get-CategoryMetric -Category 'Admins' -Data @('admin1')
                $result | Should -Be '1 admin'
            }

            InModuleScope PSSymantecSEPM {
                $result = Get-CategoryMetric -Category 'Admins' -Data @('admin1', 'admin2')
                $result | Should -Be '2 admins'
            }
        }

        It 'returns data type for DatabaseInfo' {
            InModuleScope PSSymantecSEPM {
                $result = Get-CategoryMetric -Category 'DatabaseInfo' -Data @{ type = 'MySQL' }
                $result | Should -Be 'MySQL'
            }
        }

        It 'returns product name for License' {
            InModuleScope PSSymantecSEPM {
                $result = Get-CategoryMetric -Category 'License' -Data @{ productName = 'Symantec Endpoint Protection' }
                $result | Should -Be 'Symantec Endpoint Protection'
            }
        }

        It 'returns license type for LicenseSummary' {
            InModuleScope PSSymantecSEPM {
                $result = Get-CategoryMetric -Category 'LicenseSummary' -Data @{ license_type = 'evaluation' }
                $result | Should -Be 'evaluation'
            }
        }

        It 'returns count with site(s) for ReplicationStatus' {
            InModuleScope PSSymantecSEPM {
                $result = Get-CategoryMetric -Category 'ReplicationStatus' -Data @('site1', 'site2', 'site3')
                $result | Should -Be '3 sites'
            }

            InModuleScope PSSymantecSEPM {
                $result = Get-CategoryMetric -Category 'ReplicationStatus' -Data @('site1')
                $result | Should -Be '1 site'
            }
        }

        It 'returns count with stat(s) for ThreatStats' {
            InModuleScope PSSymantecSEPM {
                $result = Get-CategoryMetric -Category 'ThreatStats' -Data @('stat1')
                $result | Should -Be '1 stat'
            }
        }

        It 'returns content name for LatestDefinitions' {
            InModuleScope PSSymantecSEPM {
                $result = Get-CategoryMetric -Category 'LatestDefinitions' -Data @{ contentName = '20240401-001' }
                $result | Should -Be '20240401-001'
            }
        }

        It 'returns count with event(s) for Events' {
            InModuleScope PSSymantecSEPM {
                $result = Get-CategoryMetric -Category 'Events' -Data @('event1', 'event2')
                $result | Should -Be '2 events'
            }
        }

        It 'PolicySummaries returns policy/policies' {
            InModuleScope PSSymantecSEPM {
                $result = Get-CategoryMetric -Category 'PolicySummaries' -Data @('p1')
                $result | Should -Be '1 policy'
            }

            InModuleScope PSSymantecSEPM {
                $result = Get-CategoryMetric -Category 'PolicySummaries' -Data @('p1', 'p2')
                $result | Should -Be '2 policies'
            }
        }

        It 'FirewallPolicies returns policy/policies' {
            InModuleScope PSSymantecSEPM {
                $result = Get-CategoryMetric -Category 'FirewallPolicies' -Data @('p1')
                $result | Should -Be '1 policy'
            }
        }

        It 'IpsPolicies returns policy/policies' {
            InModuleScope PSSymantecSEPM {
                $result = Get-CategoryMetric -Category 'IpsPolicies' -Data @('p1', 'p2', 'p3')
                $result | Should -Be '3 policies'
            }
        }

        It 'ExceptionPolicies returns policy/policies' {
            InModuleScope PSSymantecSEPM {
                $result = Get-CategoryMetric -Category 'ExceptionPolicies' -Data @('p1')
                $result | Should -Be '1 policy'
            }
        }

        It 'Computers returns computer(s)' {
            InModuleScope PSSymantecSEPM {
                $result = Get-CategoryMetric -Category 'Computers' -Data @('c1', 'c2')
                $result | Should -Be '2 computers'
            }
        }

        It 'ClientStatus returns status/statuses' {
            InModuleScope PSSymantecSEPM {
                $result = Get-CategoryMetric -Category 'ClientStatus' -Data @('s1')
                $result | Should -Be '1 status'
            }

            InModuleScope PSSymantecSEPM {
                $result = Get-CategoryMetric -Category 'ClientStatus' -Data @('s1', 's2')
                $result | Should -Be '2 statuses'
            }
        }

        It 'ClientVersions returns entry/entries' {
            InModuleScope PSSymantecSEPM {
                $result = Get-CategoryMetric -Category 'ClientVersions' -Data @('v1')
                $result | Should -Be '1 entry'
            }

            InModuleScope PSSymantecSEPM {
                $result = Get-CategoryMetric -Category 'ClientVersions' -Data @('v1', 'v2', 'v3')
                $result | Should -Be '3 entries'
            }
        }

        It 'ClientDefVersions returns entry/entries' {
            InModuleScope PSSymantecSEPM {
                $result = Get-CategoryMetric -Category 'ClientDefVersions' -Data @('d1')
                $result | Should -Be '1 entry'
            }
        }

        It 'ClientInfected returns client(s)' {
            InModuleScope PSSymantecSEPM {
                $result = Get-CategoryMetric -Category 'ClientInfected' -Data @('client1')
                $result | Should -Be '1 client'
            }
        }

        It 'Groups returns group(s)' {
            InModuleScope PSSymantecSEPM {
                $result = Get-CategoryMetric -Category 'Groups' -Data @('g1', 'g2')
                $result | Should -Be '2 groups'
            }
        }

        It 'Locations returns location(s)' {
            InModuleScope PSSymantecSEPM {
                $result = Get-CategoryMetric -Category 'Locations' -Data @('loc1', 'loc2', 'loc3')
                $result | Should -Be '3 locations'
            }
        }

        It 'LocationXML returns entry/entries' {
            InModuleScope PSSymantecSEPM {
                $result = Get-CategoryMetric -Category 'LocationXML' -Data @('xml1')
                $result | Should -Be '1 entry'
            }
        }

        It 'GroupSettings returns entry/entries' {
            InModuleScope PSSymantecSEPM {
                $result = Get-CategoryMetric -Category 'GroupSettings' -Data @('gs1', 'gs2')
                $result | Should -Be '2 entries'
            }
        }

        It 'HostGroups returns group(s)' {
            InModuleScope PSSymantecSEPM {
                $result = Get-CategoryMetric -Category 'HostGroups' -Data @('hg1')
                $result | Should -Be '1 group'
            }
        }

        It 'Snapshot returns "snapshot written"' {
            InModuleScope PSSymantecSEPM {
                $result = Get-CategoryMetric -Category 'Snapshot' -Data 'written'
                $result | Should -Be 'snapshot written'
            }
        }

        It 'returns version string from Version hashtable' {
            InModuleScope PSSymantecSEPM {
                $result = Get-CategoryMetric -Category 'Version' -Data @{ API_VERSION = '14.3.0.0'; version = '14.3.0.0' }
                $result | Should -Be '14.3.0.0'
            }
        }

        It 'falls back to API_VERSION for Version hashtable' {
            InModuleScope PSSymantecSEPM {
                $result = Get-CategoryMetric -Category 'Version' -Data @{ API_VERSION = '14.3' }
                $result | Should -Be '14.3'
            }
        }

        It 'default category returns count entries' {
            InModuleScope PSSymantecSEPM {
                $result = Get-CategoryMetric -Category 'UnknownCategory' -Data @('a', 'b')
                $result | Should -Be '2 entries'
            }
        }

        It 'empty array returns 0 count' {
            InModuleScope PSSymantecSEPM {
                $result = Get-CategoryMetric -Category 'Domains' -Data @()
                $result | Should -Be '0 domains'
            }
        }
    }
}
