[CmdletBinding()]
param()

Describe 'Export-SEPMInventory' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment

        # ── Shared base mocks for all contexts ──
        $fakeSession = New-TestSession
        Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }

        Mock Get-SEPMVersion -ModuleName PSSymantecSEPM {
            return @{ API_SEQUENCE = '230504014'; API_VERSION = '14.3.7000'; version = '14.3.9816.7000' }
        }
        Mock Get-SEPMDomain -ModuleName PSSymantecSEPM {
            return @{ id = 'abc123'; name = 'Default' }
        }
        # Infrastructure & Security mocks (return $null by default — contexts override as needed)
        Mock Get-SEPGUPList -ModuleName PSSymantecSEPM {
            Write-Output @(@{ name = 'GUP1'; host = 'gup1.example.com' }) -NoEnumerate
        }
        Mock Get-SEPMAdmins -ModuleName PSSymantecSEPM {
            Write-Output @(@{ loginName = 'admin'; loginDomain = 'Default'; fullName = 'Administrator' }) -NoEnumerate
        }
        Mock Get-SEPMDatabaseInfo -ModuleName PSSymantecSEPM {
            return @{ type = 'embedded'; version = '11.0' }
        }
        Mock Get-SEPMLicense -ModuleName PSSymantecSEPM {
            return @{ serialNumber = 'BXXXXXXXXXX'; seats = 10000; productName = 'Symantec Endpoint Security Complete' }
        }
        Mock Get-SEPMReplicationStatus -ModuleName PSSymantecSEPM {
            Write-Output @(@{ siteName = 'Site1'; replicationStatus = 'OK' }) -NoEnumerate
        }
        Mock Get-SEPMThreatStats -ModuleName PSSymantecSEPM {
            Write-Output @(@{ infectedClients = '5'; lastUpdated = '1700000000000' }) -NoEnumerate
        }
        Mock Get-SEPMLatestDefinition -ModuleName PSSymantecSEPM {
            return @{ contentName = 'AV_DEFS'; publishedBySEPM = '6/23/2026 rev. 3' }
        }
        Mock Get-SEPMEventInfo -ModuleName PSSymantecSEPM {
            Write-Output @(@{ subject = 'Password warning'; eventId = 'EVT001' }) -NoEnumerate
        }

        # Policy mocks (return empty by default — contexts override as needed)
        Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM {
            Write-Output @() -NoEnumerate
        }
        Mock Get-SEPMFirewallPolicy -ModuleName PSSymantecSEPM {
            Write-Output @() -NoEnumerate
        }
        Mock Get-SEPMIpsPolicy -ModuleName PSSymantecSEPM {
            return $null
        }
        Mock Get-SEPMExceptionPolicy -ModuleName PSSymantecSEPM {
            return $null
        }
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Snapshot shape' {
        BeforeAll {
            # LicenseSummary needs separate mock since Get-SEPMLicense base mock doesn't cover -Summary
            Mock Get-SEPMLicense -ModuleName PSSymantecSEPM {
                if ($Summary) {
                    return @{ license_type = 'PAID'; serial_number = 'BXXXXXXXXXX' }
                }
                return @{ serialNumber = 'BXXXXXXXXXX'; seats = 10000; productName = 'Symantec Endpoint Security Complete' }
            }
        }

        It 'returns snapshot with SEPM.Inventory PSTypeName' {
            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $result.PSObject.TypeNames[0] | Should -Be 'SEPM.Inventory'
        }

        It 'FetchedAt is a [DateTime]' {
            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $result.FetchedAt | Should -BeOfType [DateTime]
        }

        It 'snapshot contains all infrastructure & security properties' {
            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $result.GUPs                | Should -Not -BeNullOrEmpty
            $result.Admins              | Should -Not -BeNullOrEmpty
            $result.DatabaseInfo        | Should -Not -BeNullOrEmpty
            $result.License             | Should -Not -BeNullOrEmpty
            $result.LicenseSummary      | Should -Not -BeNullOrEmpty
            $result.ReplicationStatus   | Should -Not -BeNullOrEmpty
            $result.ThreatStats         | Should -Not -BeNullOrEmpty
            $result.LatestDefinitions   | Should -Not -BeNullOrEmpty
            $result.Events              | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Sub-cmdlet data gathering' {
        BeforeAll {
            Mock Get-SEPMLicense -ModuleName PSSymantecSEPM {
                if ($Summary) {
                    return @{ license_type = 'PAID'; serial_number = 'BXXXXXXXXXX' }
                }
                return @{ serialNumber = 'BXXXXXXXXXX'; seats = 10000; productName = 'Symantec Endpoint Security Complete' }
            }
        }

        It 'stores Get-SEPMVersion output in Version property' {
            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $result.Version.API_SEQUENCE | Should -Be '230504014'
            $result.Version.API_VERSION  | Should -Be '14.3.7000'
            $result.Version.version      | Should -Be '14.3.9816.7000'
        }

        It 'stores Get-SEPMDomain output in Domains property' {
            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $result.Domains.id   | Should -Be 'abc123'
            $result.Domains.name | Should -Be 'Default'
        }

        It 'stores Get-SEPGUPList output in GUPs property' {
            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $result.GUPs.Count      | Should -Be 1
            $result.GUPs[0].name    | Should -Be 'GUP1'
            $result.GUPs[0].host    | Should -Be 'gup1.example.com'
        }

        It 'stores Get-SEPMAdmins output in Admins property' {
            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $result.Admins.Count        | Should -Be 1
            $result.Admins[0].loginName | Should -Be 'admin'
        }

        It 'stores Get-SEPMDatabaseInfo output in DatabaseInfo property' {
            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $result.DatabaseInfo.type    | Should -Be 'embedded'
            $result.DatabaseInfo.version | Should -Be '11.0'
        }

        It 'stores Get-SEPMLicense output in License property' {
            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $result.License.serialNumber | Should -Be 'BXXXXXXXXXX'
            $result.License.seats        | Should -Be 10000
        }

        It 'stores Get-SEPMLicense -Summary output in LicenseSummary property' {
            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $result.LicenseSummary.license_type | Should -Be 'PAID'
        }

        It 'stores Get-SEPMReplicationStatus output in ReplicationStatus property' {
            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $result.ReplicationStatus.Count              | Should -Be 1
            $result.ReplicationStatus[0].siteName         | Should -Be 'Site1'
        }

        It 'stores Get-SEPMThreatStats output in ThreatStats property' {
            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $result.ThreatStats.Count               | Should -Be 1
            $result.ThreatStats[0].infectedClients   | Should -Be '5'
        }

        It 'stores Get-SEPMLatestDefinition output in LatestDefinitions property' {
            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $result.LatestDefinitions.contentName     | Should -Be 'AV_DEFS'
            $result.LatestDefinitions.publishedBySEPM | Should -Be '6/23/2026 rev. 3'
        }

        It 'stores Get-SEPMEventInfo output in Events property' {
            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $result.Events.Count        | Should -Be 1
            $result.Events[0].subject    | Should -Be 'Password warning'
        }

        It 'stores Get-SEPMPoliciesSummary output in PolicySummaries property' {
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM {
                Write-Output @(
                    @{ id = 'P001'; name = 'AV Policy'; policytype = 'av'; enabled = $true }
                    @{ id = 'P002'; name = 'FW Policy'; policytype = 'fw'; enabled = $true }
                ) -NoEnumerate
            }

            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $result.PolicySummaries | Should -Not -BeNullOrEmpty
            $result.PolicySummaries.Count | Should -Be 2
            $result.PolicySummaries[0].name | Should -Be 'AV Policy'
            $result.PolicySummaries[1].name | Should -Be 'FW Policy'
        }

        It 'stores Get-SEPMFirewallPolicy -All output in FirewallPolicies property' {
            Mock Get-SEPMFirewallPolicy -ModuleName PSSymantecSEPM {
                Write-Output @(
                    @{ name = 'FW Policy 1'; id = 'F001' }
                    @{ name = 'FW Policy 2'; id = 'F002' }
                ) -NoEnumerate
            }

            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $result.FirewallPolicies | Should -Not -BeNullOrEmpty
            $result.FirewallPolicies.Count | Should -Be 2
            $result.FirewallPolicies[0].name | Should -Be 'FW Policy 1'
            $result.FirewallPolicies[1].name | Should -Be 'FW Policy 2'
        }

        It 'stores per-policy Get-SEPMIpsPolicy results in IpsPolicies property' {
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM {
                Write-Output @(
                    @{ id = 'I001'; name = 'IPS Policy A'; policytype = 'ips'; enabled = $true }
                    @{ id = 'I002'; name = 'IPS Policy B'; policytype = 'ips'; enabled = $true }
                ) -NoEnumerate
            }
            $script:ipsCallCount = 0
            Mock Get-SEPMIpsPolicy -ModuleName PSSymantecSEPM {
                $script:ipsCallCount++
                if ($PolicyName -eq 'IPS Policy A') { return @{ name = 'IPS Policy A'; configuration = @{ blocked_hosts = @() } } }
                if ($PolicyName -eq 'IPS Policy B') { return @{ name = 'IPS Policy B'; configuration = @{ blocked_hosts = @() } } }
                return $null
            }

            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $result.IpsPolicies | Should -Not -BeNullOrEmpty
            $result.IpsPolicies.Count | Should -Be 2
            $result.IpsPolicies[0].name | Should -Be 'IPS Policy A'
            $result.IpsPolicies[1].name | Should -Be 'IPS Policy B'
            $script:ipsCallCount | Should -Be 2
        }

        It 'stores per-policy Get-SEPMExceptionPolicy results in ExceptionPolicies property' {
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM {
                Write-Output @(
                    @{ id = 'E001'; name = 'Exception Policy X'; policytype = 'exceptions'; enabled = $true }
                    @{ id = 'E002'; name = 'Exception Policy Y'; policytype = 'exceptions'; enabled = $true }
                ) -NoEnumerate
            }
            $script:excCallCount = 0
            Mock Get-SEPMExceptionPolicy -ModuleName PSSymantecSEPM {
                $script:excCallCount++
                if ($PolicyName -eq 'Exception Policy X') { return @{ name = 'Exception Policy X'; configuration = @{ files = @() } } }
                if ($PolicyName -eq 'Exception Policy Y') { return @{ name = 'Exception Policy Y'; configuration = @{ files = @() } } }
                return $null
            }

            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $result.ExceptionPolicies | Should -Not -BeNullOrEmpty
            $result.ExceptionPolicies.Count | Should -Be 2
            $result.ExceptionPolicies[0].name | Should -Be 'Exception Policy X'
            $result.ExceptionPolicies[1].name | Should -Be 'Exception Policy Y'
            $script:excCallCount | Should -Be 2
        }
    }

    Context 'Per-category .clixml output' {
        BeforeAll {
            Mock Get-SEPMLicense -ModuleName PSSymantecSEPM {
                if ($Summary) {
                    return @{ license_type = 'PAID'; serial_number = 'BXXXXXXXXXX' }
                }
                return @{ serialNumber = 'BXXXXXXXXXX'; seats = 10000; productName = 'Symantec Endpoint Security Complete' }
            }
        }

        It 'writes all_version.xml' {
            Export-SEPMInventory -OutputDir 'TestDrive:' | Out-Null
            Join-Path -Path 'TestDrive:' -ChildPath 'all_version.xml' | Should -Exist
        }

        It 'writes all_domains.xml' {
            Export-SEPMInventory -OutputDir 'TestDrive:' | Out-Null
            Join-Path -Path 'TestDrive:' -ChildPath 'all_domains.xml' | Should -Exist
        }

        It 'writes all_policy_summaries.xml' {
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM {
                Write-Output @() -NoEnumerate
            }
            Export-SEPMInventory -OutputDir 'TestDrive:' | Out-Null
            Join-Path -Path 'TestDrive:' -ChildPath 'all_policy_summaries.xml' | Should -Exist
        }

        It 'writes all_fw_policies.xml' {
            Mock Get-SEPMFirewallPolicy -ModuleName PSSymantecSEPM {
                Write-Output @() -NoEnumerate
            }
            Export-SEPMInventory -OutputDir 'TestDrive:' | Out-Null
            Join-Path -Path 'TestDrive:' -ChildPath 'all_fw_policies.xml' | Should -Exist
        }

        It 'writes all_ips_policies.xml' {
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM {
                Write-Output @(
                    @{ id = 'I001'; name = 'IPS Policy'; policytype = 'ips'; enabled = $true }
                ) -NoEnumerate
            }
            Mock Get-SEPMIpsPolicy -ModuleName PSSymantecSEPM {
                return @{ name = 'IPS Policy'; configuration = @{ blocked_hosts = @() } }
            }
            Export-SEPMInventory -OutputDir 'TestDrive:' | Out-Null
            Join-Path -Path 'TestDrive:' -ChildPath 'all_ips_policies.xml' | Should -Exist
        }

        It 'writes all_exception_policies.xml' {
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM {
                Write-Output @(
                    @{ id = 'E001'; name = 'Exception Policy'; policytype = 'exceptions'; enabled = $true }
                ) -NoEnumerate
            }
            Mock Get-SEPMExceptionPolicy -ModuleName PSSymantecSEPM {
                return @{ name = 'Exception Policy'; configuration = @{ files = @() } }
            }
            Export-SEPMInventory -OutputDir 'TestDrive:' | Out-Null
            Join-Path -Path 'TestDrive:' -ChildPath 'all_exception_policies.xml' | Should -Exist
        }

        It 'writes policy .clixml files' {
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM {
                Write-Output @() -NoEnumerate
            }
            Mock Get-SEPMFirewallPolicy -ModuleName PSSymantecSEPM {
                Write-Output @() -NoEnumerate
            }
            Export-SEPMInventory -OutputDir 'TestDrive:' | Out-Null
            Join-Path -Path 'TestDrive:' -ChildPath 'all_policy_summaries.xml' | Should -Exist
            Join-Path -Path 'TestDrive:' -ChildPath 'all_fw_policies.xml' | Should -Exist
            Join-Path -Path 'TestDrive:' -ChildPath 'all_ips_policies.xml' | Should -Exist
            Join-Path -Path 'TestDrive:' -ChildPath 'all_exception_policies.xml' | Should -Exist
        }

        It 'writes infrastructure & security .clixml files' {
            Export-SEPMInventory -OutputDir 'TestDrive:' | Out-Null
            Join-Path -Path 'TestDrive:' -ChildPath 'all_gups.xml'               | Should -Exist
            Join-Path -Path 'TestDrive:' -ChildPath 'all_admins.xml'             | Should -Exist
            Join-Path -Path 'TestDrive:' -ChildPath 'all_database_info.xml'      | Should -Exist
            Join-Path -Path 'TestDrive:' -ChildPath 'all_license.xml'            | Should -Exist
            Join-Path -Path 'TestDrive:' -ChildPath 'all_license_summary.xml'    | Should -Exist
            Join-Path -Path 'TestDrive:' -ChildPath 'all_replication_status.xml' | Should -Exist
            Join-Path -Path 'TestDrive:' -ChildPath 'all_threat_stats.xml'       | Should -Exist
            Join-Path -Path 'TestDrive:' -ChildPath 'all_latest_definitions.xml' | Should -Exist
            Join-Path -Path 'TestDrive:' -ChildPath 'all_events.xml'             | Should -Exist
        }
    }

    Context 'Timestamped snapshot blob' {
        BeforeAll {
            Mock Get-SEPMLicense -ModuleName PSSymantecSEPM {
                if ($Summary) {
                    return @{ license_type = 'PAID'; serial_number = 'BXXXXXXXXXX' }
                }
                return @{ serialNumber = 'BXXXXXXXXXX'; seats = 10000; productName = 'Symantec Endpoint Security Complete' }
            }
        }

        It 'writes a timestamped .clixml blob' {
            Export-SEPMInventory -OutputDir 'TestDrive:' | Out-Null
            $blobs = Get-ChildItem -Path 'TestDrive:' -Filter 'SepmInventory_*.clixml'
            $blobs.Count | Should -BeGreaterThan 0
        }

        It 'blob content round-trips with SEPM.Inventory PSTypeName' {
            Export-SEPMInventory -OutputDir 'TestDrive:' | Out-Null
            $blobs = Get-ChildItem -Path 'TestDrive:' -Filter 'SepmInventory_*.clixml'
            $imported = Import-Clixml -Path $blobs[0].FullName
            $imported.PSObject.TypeNames[0] | Should -Be 'Deserialized.SEPM.Inventory'
            $imported.FetchedAt | Should -BeOfType [DateTime]
            $imported.Version.version | Should -Be '14.3.9816.7000'
        }

        It 'blob filename includes ISO 8601 timestamp' {
            Export-SEPMInventory -OutputDir 'TestDrive:' | Out-Null
            $blobs = Get-ChildItem -Path 'TestDrive:' -Filter 'SepmInventory_*.clixml'
            $blobs[0].Name | Should -Match '^SepmInventory_\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}\.clixml$'
        }
    }

    Context 'Failure capture' {
        BeforeAll {
            Mock Get-SEPMLicense -ModuleName PSSymantecSEPM {
                if ($Summary) {
                    return @{ license_type = 'PAID'; serial_number = 'BXXXXXXXXXX' }
                }
                return @{ serialNumber = 'BXXXXXXXXXX'; seats = 10000; productName = 'Symantec Endpoint Security Complete' }
            }
        }

        It 'captures infrastructure failure in Failures array' {
            Mock Get-SEPGUPList -ModuleName PSSymantecSEPM { throw 'GUP API unavailable' }

            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $result.Failures.Count | Should -Be 1
            $result.Failures[0].Category | Should -Be 'GUPs'
            $result.Failures[0].Error    | Should -Be 'GUP API unavailable'
            $result.GUPs | Should -BeNullOrEmpty
        }

        It 'writes _failed.xml for infrastructure failures' {
            Mock Get-SEPMAdmins -ModuleName PSSymantecSEPM { throw 'Admins API unavailable' }

            Get-ChildItem -Path 'TestDrive:' -Filter '*_failed.xml' | Remove-Item -Force -ErrorAction SilentlyContinue
            Export-SEPMInventory -OutputDir 'TestDrive:' | Out-Null
            Join-Path -Path 'TestDrive:' -ChildPath 'Admins_failed.xml' | Should -Exist
        }

        It 'captures PolicySummaries failure in Failures array' {
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM { throw 'Policies API unavailable' }

            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $result.Failures | Where-Object { $_.Category -eq 'PolicySummaries' } | Should -Not -BeNullOrEmpty
            $result.Failures[0].Error | Should -Be 'Policies API unavailable'
        }

        It 'writes PolicySummaries_failed.xml on failure' {
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM { throw 'Policies API error' }

            Get-ChildItem -Path 'TestDrive:' -Filter '*_failed.xml' | Remove-Item -Force -ErrorAction SilentlyContinue
            Export-SEPMInventory -OutputDir 'TestDrive:' | Out-Null
            Join-Path -Path 'TestDrive:' -ChildPath 'PolicySummaries_failed.xml' | Should -Exist
        }

        It 'captures per-policy IPS failure and continues with remaining policies' {
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM {
                Write-Output @(
                    @{ id = 'I001'; name = 'Working IPS'; policytype = 'ips'; enabled = $true }
                    @{ id = 'I002'; name = 'Failing IPS'; policytype = 'ips'; enabled = $true }
                    @{ id = 'I003'; name = 'Another IPS'; policytype = 'ips'; enabled = $true }
                ) -NoEnumerate
            }
            $script:ipsFailCallCount = 0
            Mock Get-SEPMIpsPolicy -ModuleName PSSymantecSEPM {
                $script:ipsFailCallCount++
                if ($PolicyName -eq 'Failing IPS') { throw 'IPS API error' }
                return @{ name = $PolicyName; configuration = @{ blocked_hosts = @() } }
            }

            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $ipsFailures = $result.Failures | Where-Object { $_.Category -eq 'IpsPolicies' }
            $ipsFailures.Count | Should -Be 1
            $ipsFailures[0].PolicyName | Should -Be 'Failing IPS'
            $result.IpsPolicies.Count | Should -Be 2
        }

        It 'captures per-policy exception failure and continues with remaining policies' {
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM {
                Write-Output @(
                    @{ id = 'E001'; name = 'Good Exc'; policytype = 'exceptions'; enabled = $true }
                    @{ id = 'E002'; name = 'Bad Exc'; policytype = 'exceptions'; enabled = $true }
                ) -NoEnumerate
            }
            $script:excFailCallCount = 0
            Mock Get-SEPMExceptionPolicy -ModuleName PSSymantecSEPM {
                $script:excFailCallCount++
                if ($PolicyName -eq 'Bad Exc') { throw 'Exception API error' }
                return @{ name = $PolicyName; configuration = @{ files = @() } }
            }

            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $excFailures = $result.Failures | Where-Object { $_.Category -eq 'ExceptionPolicies' }
            $excFailures.Count | Should -Be 1
            $excFailures[0].PolicyName | Should -Be 'Bad Exc'
            $result.ExceptionPolicies.Count | Should -Be 1
        }

        It 'writes IpsPolicies_failed.xml on per-policy IPS failure' {
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM {
                Write-Output @(
                    @{ id = 'I001'; name = 'Failing IPS'; policytype = 'ips'; enabled = $true }
                ) -NoEnumerate
            }
            Mock Get-SEPMIpsPolicy -ModuleName PSSymantecSEPM { throw 'IPS error' }

            Get-ChildItem -Path 'TestDrive:' -Filter '*_failed.xml' | Remove-Item -Force -ErrorAction SilentlyContinue
            Export-SEPMInventory -OutputDir 'TestDrive:' | Out-Null
            Join-Path -Path 'TestDrive:' -ChildPath 'IpsPolicies_failed.xml' | Should -Exist
        }

        It 'writes ExceptionPolicies_failed.xml on per-policy exception failure' {
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM {
                Write-Output @(
                    @{ id = 'E001'; name = 'Failing Exc'; policytype = 'exceptions'; enabled = $true }
                ) -NoEnumerate
            }
            Mock Get-SEPMExceptionPolicy -ModuleName PSSymantecSEPM { throw 'Exception error' }

            Get-ChildItem -Path 'TestDrive:' -Filter '*_failed.xml' | Remove-Item -Force -ErrorAction SilentlyContinue
            Export-SEPMInventory -OutputDir 'TestDrive:' | Out-Null
            Join-Path -Path 'TestDrive:' -ChildPath 'ExceptionPolicies_failed.xml' | Should -Exist
        }
    }

    Context 'OutputDir parameter' {
        BeforeAll {
            Mock Get-SEPMLicense -ModuleName PSSymantecSEPM {
                if ($Summary) {
                    return @{ license_type = 'PAID'; serial_number = 'BXXXXXXXXXX' }
                }
                return @{ serialNumber = 'BXXXXXXXXXX'; seats = 10000; productName = 'Symantec Endpoint Security Complete' }
            }

            # Ensure policy mocks don't throw when collecting output
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM {
                Write-Output @() -NoEnumerate
            }
            Mock Get-SEPMFirewallPolicy -ModuleName PSSymantecSEPM {
                Write-Output @() -NoEnumerate
            }
        }

        It 'writes files to the specified OutputDir' {
            $customDir = Join-Path -Path 'TestDrive:' -ChildPath 'custom_inventory'
            New-Item -Path $customDir -ItemType Directory -Force | Out-Null
            Export-SEPMInventory -OutputDir $customDir | Out-Null

            Join-Path -Path $customDir -ChildPath 'all_version.xml' | Should -Exist
            Join-Path -Path $customDir -ChildPath 'all_domains.xml' | Should -Exist
            Join-Path -Path $customDir -ChildPath 'all_gups.xml'    | Should -Exist
        }
    }

    Context 'DelayMs parameter' {
        BeforeAll {
            Mock Get-SEPMLicense -ModuleName PSSymantecSEPM {
                if ($Summary) {
                    return @{ license_type = 'PAID'; serial_number = 'BXXXXXXXXXX' }
                }
                return @{ serialNumber = 'BXXXXXXXXXX'; seats = 10000; productName = 'Symantec Endpoint Security Complete' }
            }
        }

        It 'calls Get-SEPMVersion then Get-SEPMDomain with delay' {
            $script:callOrder = @()
            Mock Get-SEPMVersion -ModuleName PSSymantecSEPM {
                $script:callOrder += 'Version'
                return @{ API_SEQUENCE = '230504014'; API_VERSION = '14.3.7000'; version = '14.3.9816.7000' }
            }
            Mock Get-SEPMDomain -ModuleName PSSymantecSEPM {
                $script:callOrder += 'Domains'
                return @{ id = 'abc123'; name = 'Default' }
            }

            Export-SEPMInventory -OutputDir 'TestDrive:' -DelayMs 1 | Out-Null
            $script:callOrder[0] | Should -Be 'Version'
            $script:callOrder[1] | Should -Be 'Domains'
        }

        It 'respects DelayMs between per-policy IPS fetches' {
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM {
                Write-Output @(
                    @{ id = 'I001'; name = 'IPS A'; policytype = 'ips'; enabled = $true }
                    @{ id = 'I002'; name = 'IPS B'; policytype = 'ips'; enabled = $true }
                ) -NoEnumerate
            }
            $script:ipsDelayCallOrder = @()
            Mock Get-SEPMIpsPolicy -ModuleName PSSymantecSEPM {
                $script:ipsDelayCallOrder += $PolicyName
                return @{ name = $PolicyName; configuration = @{ blocked_hosts = @() } }
            }
            Mock Start-Sleep -ModuleName PSSymantecSEPM {}

            Export-SEPMInventory -OutputDir 'TestDrive:' -DelayMs 50 | Out-Null

            # At least 1 sleep for per-policy delay + top-level sleeps between sections
            Should -Invoke Start-Sleep -ModuleName PSSymantecSEPM -Scope It -ParameterFilter { $Milliseconds -eq 50 }
            $script:ipsDelayCallOrder[0] | Should -Be 'IPS A'
            $script:ipsDelayCallOrder[1] | Should -Be 'IPS B'
        }

        It 'respects DelayMs between per-policy exception fetches' {
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM {
                Write-Output @(
                    @{ id = 'E001'; name = 'Exc A'; policytype = 'exceptions'; enabled = $true }
                    @{ id = 'E002'; name = 'Exc B'; policytype = 'exceptions'; enabled = $true }
                ) -NoEnumerate
            }
            $script:excDelayCallOrder = @()
            Mock Get-SEPMExceptionPolicy -ModuleName PSSymantecSEPM {
                $script:excDelayCallOrder += $PolicyName
                return @{ name = $PolicyName; configuration = @{ files = @() } }
            }
            Mock Start-Sleep -ModuleName PSSymantecSEPM {}

            Export-SEPMInventory -OutputDir 'TestDrive:' -DelayMs 75 | Out-Null

            # At least 1 sleep for per-policy delay + top-level sleeps between sections
            Should -Invoke Start-Sleep -ModuleName PSSymantecSEPM -Scope It -ParameterFilter { $Milliseconds -eq 75 }
            $script:excDelayCallOrder[0] | Should -Be 'Exc A'
            $script:excDelayCallOrder[1] | Should -Be 'Exc B'
        }

        It 'no sleep when DelayMs is 0 (default) for per-policy fetches' {
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM {
                Write-Output @(
                    @{ id = 'I001'; name = 'IPS Only'; policytype = 'ips'; enabled = $true }
                ) -NoEnumerate
            }
            Mock Get-SEPMIpsPolicy -ModuleName PSSymantecSEPM {
                return @{ name = 'IPS Only'; configuration = @{ blocked_hosts = @() } }
            }
            Mock Start-Sleep -ModuleName PSSymantecSEPM {}

            Export-SEPMInventory -OutputDir 'TestDrive:' -DelayMs 0 | Out-Null

            Should -Invoke Start-Sleep -ModuleName PSSymantecSEPM -Exactly 0 -Scope It
        }
    }
}
