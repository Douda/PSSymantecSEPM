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

        # Client/Computer mocks (return empty by default — contexts override as needed)
        Mock Get-SEPComputers -ModuleName PSSymantecSEPM {
            Write-Output @() -NoEnumerate
        }
        Mock Get-SEPClientStatus -ModuleName PSSymantecSEPM {
            Write-Output @() -NoEnumerate
        }
        Mock Get-SEPClientVersion -ModuleName PSSymantecSEPM {
            Write-Output @() -NoEnumerate
        }
        Mock Get-SEPClientDefVersions -ModuleName PSSymantecSEPM {
            Write-Output @() -NoEnumerate
        }
        Mock Get-SEPClientInfectedStatus -ModuleName PSSymantecSEPM {
            Write-Output @() -NoEnumerate
        }

        # Groups & Locations mocks
        Mock Get-SEPMGroups -ModuleName PSSymantecSEPM {
            Write-Output @(
                [PSCustomObject]@{ id = 'GRP001'; name = 'My Company'; fullPathName = 'My Company' }
                [PSCustomObject]@{ id = 'GRP002'; name = 'Workstations'; fullPathName = 'My Company\Workstations' }
            ) -NoEnumerate
        }
        Mock Get-SEPMLocation -ModuleName PSSymantecSEPM {
            Write-Output @([PSCustomObject]@{ locationName = 'Default'; locationId = 'LOC001'; groupName = 'My Company'; groupId = 'GRP001'; groupFullPathName = 'My Company' }) -NoEnumerate
        }
        Mock Get-SEPMLocationXML -ModuleName PSSymantecSEPM {
            return $null
        }
        Mock Get-SEPMGroupSettings -ModuleName PSSymantecSEPM {
            return $null
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

        # Host Group mocks (return empty by default)
        Mock Get-SEPMHostGroupSummary -ModuleName PSSymantecSEPM {
            Write-Output @() -NoEnumerate
        }
        Mock Get-SEPMHostGroup -ModuleName PSSymantecSEPM {
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

        It 'snapshot contains Groups property with all groups' {
            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $result.Groups | Should -Not -BeNullOrEmpty
            $result.Groups.Count | Should -Be 2
            $result.Groups[0].name | Should -Be 'My Company'
            $result.Groups[1].name | Should -Be 'Workstations'
        }

        It 'snapshot contains HostGroups property' {
            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $null -ne $result.HostGroups | Should -BeTrue
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

        It 'stores Get-SEPClientInfectedStatus output in ClientInfected property' {
            Mock Get-SEPClientInfectedStatus -ModuleName PSSymantecSEPM {
                Write-Output @(
                    @{ computerName = 'INFECTED-PC-01'; infected = 1 }
                    @{ computerName = 'INFECTED-PC-02'; infected = 1 }
                ) -NoEnumerate
            }

            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $result.ClientInfected | Should -Not -BeNullOrEmpty
            $result.ClientInfected.Count | Should -Be 2
            $result.ClientInfected[0].computerName | Should -Be 'INFECTED-PC-01'
            $result.ClientInfected[1].infected | Should -Be 1
        }

        It 'stores Get-SEPClientDefVersions output in ClientDefVersions property' {
            Mock Get-SEPClientDefVersions -ModuleName PSSymantecSEPM {
                Write-Output @(
                    @{ version = '2023-09-04 rev. 002'; clientsCount = 15 }
                    @{ version = '2023-09-03 rev. 002'; clientsCount = 4 }
                ) -NoEnumerate
            }

            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $result.ClientDefVersions | Should -Not -BeNullOrEmpty
            $result.ClientDefVersions.Count | Should -Be 2
            $result.ClientDefVersions[0].version | Should -Be '2023-09-04 rev. 002'
            $result.ClientDefVersions[1].clientsCount | Should -Be 4
        }

        It 'stores Get-SEPClientVersions output in ClientVersions property' {
            Mock Get-SEPClientVersion -ModuleName PSSymantecSEPM {
                Write-Output @(
                    @{ version = '14.3.510.0000'; clientsCount = 12; formattedVersion = '14.3 (14.3) build 0000' }
                    @{ version = '14.2.1031.0100'; clientsCount = 21; formattedVersion = '14.2.1 (14.2 RU1) build 0100' }
                ) -NoEnumerate
            }

            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $result.ClientVersions | Should -Not -BeNullOrEmpty
            $result.ClientVersions.Count | Should -Be 2
            $result.ClientVersions[0].version | Should -Be '14.3.510.0000'
            $result.ClientVersions[1].clientsCount | Should -Be 21
        }

        It 'stores Get-SEPClientStatus output in ClientStatus property' {
            Mock Get-SEPClientStatus -ModuleName PSSymantecSEPM {
                Write-Output @(
                    @{ status = 'ONLINE'; clientsCount = 10 }
                    @{ status = 'OFFLINE'; clientsCount = 3 }
                ) -NoEnumerate
            }

            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $result.ClientStatus | Should -Not -BeNullOrEmpty
            $result.ClientStatus.Count | Should -Be 2
            $result.ClientStatus[0].status | Should -Be 'ONLINE'
            $result.ClientStatus[1].clientsCount | Should -Be 3
        }

        It 'stores Get-SEPComputers output in Computers property' {
            Mock Get-SEPComputers -ModuleName PSSymantecSEPM {
                Write-Output @(
                    @{ computerName = 'PC-001'; group = @{ name = 'My Company' }; infected = 0 }
                    @{ computerName = 'PC-002'; group = @{ name = 'My Company' }; infected = 1 }
                ) -NoEnumerate
            }

            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $result.Computers | Should -Not -BeNullOrEmpty
            $result.Computers.Count | Should -Be 2
            $result.Computers[0].computerName | Should -Be 'PC-001'
            $result.Computers[1].computerName | Should -Be 'PC-002'
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

        It 'calls Get-SEPMFirewallPolicy with -SuppressProgress:$true' {
            Mock Get-SEPMFirewallPolicy -ModuleName PSSymantecSEPM {
                Write-Output @() -NoEnumerate
            }

            Export-SEPMInventory -OutputDir 'TestDrive:' | Out-Null

            Should -Invoke Get-SEPMFirewallPolicy -ModuleName PSSymantecSEPM -Scope It -Exactly 1 -ParameterFilter {
                $All -eq $true -and $SuppressProgress -eq $true
            }
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

    Context 'Host Groups data gathering' {
        BeforeAll {
            Mock Get-SEPMLicense -ModuleName PSSymantecSEPM {
                if ($Summary) {
                    return @{ license_type = 'PAID'; serial_number = 'BXXXXXXXXXX' }
                }
                return @{ serialNumber = 'BXXXXXXXXXX'; seats = 10000; productName = 'Symantec Endpoint Security Complete' }
            }
        }

        It 'HostGroups contains full detail for each Host Group from summary' {
            Mock Get-SEPMHostGroupSummary -ModuleName PSSymantecSEPM {
                Write-Output @(
                    [PSCustomObject]@{ id = 'HG001'; name = 'Web Servers'; domainid = 'DOM001'; lastmodifiedtime = 1700000000000 }
                    [PSCustomObject]@{ id = 'HG002'; name = 'DB Servers'; domainid = 'DOM001'; lastmodifiedtime = 1700000000001 }
                ) -NoEnumerate
            }
            $script:hgCallCount = 0
            Mock Get-SEPMHostGroup -ModuleName PSSymantecSEPM {
                $script:hgCallCount++
                if ($Id -eq 'HG001') {
                    return [PSCustomObject]@{
                        id = 'HG001'
                        name = 'Web Servers'
                        hosts = @(
                            @{ mac = '00:11:22:33:44:55'; ipv4 = '10.0.1.10'; dnsHost = 'web1'; dnsDomain = 'example.com' }
                            @{ mac = '00:11:22:33:44:66'; ipv6 = 'fe80::1'; dnsHost = 'web2'; dnsDomain = 'example.com' }
                        )
                    }
                }
                if ($Id -eq 'HG002') {
                    return [PSCustomObject]@{
                        id = 'HG002'
                        name = 'DB Servers'
                        hosts = @(
                            @{ mac = '00:AA:BB:CC:DD:EE'; ipv4 = '10.0.2.10'; dnsHost = 'db1'; dnsDomain = 'example.com' }
                        )
                    }
                }
                return $null
            }

            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $result.HostGroups | Should -Not -BeNullOrEmpty
            $result.HostGroups.Count | Should -Be 2
            $result.HostGroups[0].name | Should -Be 'Web Servers'
            $result.HostGroups[1].name | Should -Be 'DB Servers'
            $script:hgCallCount | Should -Be 2
        }

        It 'host groups handles pagination (more than 50 Host Groups)' {
            $hgIds = 1..60 | ForEach-Object { [PSCustomObject]@{ id = "HG$(([String]$_).PadLeft(3,'0'))"; name = "Host Group $_"; domainid = 'DOM001'; lastmodifiedtime = 1700000000000 } }
            Mock Get-SEPMHostGroupSummary -ModuleName PSSymantecSEPM {
                Write-Output $hgIds -NoEnumerate
            }
            Mock Get-SEPMHostGroup -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ id = $Id; name = "Host Group Detail"; hosts = @(@{ mac = '00:11:22:33:44:55'; ipv4 = '10.0.1.10' }) }
            }

            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $result.HostGroups | Should -Not -BeNullOrEmpty
            $result.HostGroups.Count | Should -Be 60
        }

        It 'each Host Group includes hosts[] array with network entities' {
            Mock Get-SEPMHostGroupSummary -ModuleName PSSymantecSEPM {
                Write-Output @(
                    [PSCustomObject]@{ id = 'HG001'; name = 'Web Servers'; domainid = 'DOM001'; lastmodifiedtime = 1700000000000 }
                ) -NoEnumerate
            }
            Mock Get-SEPMHostGroup -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{
                    id = 'HG001'
                    name = 'Web Servers'
                    hosts = @(
                        @{ mac = '00:11:22:33:44:55'; ipv4 = '10.0.1.10'; dnsHost = 'web1'; dnsDomain = 'example.com' }
                        @{ ipv4 = '10.0.1.11'; ipv6 = 'fe80::1' }
                        @{ name = 'DMZ Subnet'; ipRange = '10.0.1.0-10.0.1.255'; ipSubnet = '255.255.255.0' }
                    )
                }
            }

            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $result.HostGroups | Should -Not -BeNullOrEmpty
            $result.HostGroups[0].hosts | Should -Not -BeNullOrEmpty
            $result.HostGroups[0].hosts.Count | Should -Be 3
            $result.HostGroups[0].hosts[0].mac | Should -Be '00:11:22:33:44:55'
            $result.HostGroups[0].hosts[0].ipv4 | Should -Be '10.0.1.10'
            $result.HostGroups[0].hosts[1].ipv6 | Should -Be 'fe80::1'
            $result.HostGroups[0].hosts[2].ipRange | Should -Be '10.0.1.0-10.0.1.255'
        }
    }

    Context 'Groups & Locations data gathering' {
        BeforeAll {
            Mock Get-SEPMLicense -ModuleName PSSymantecSEPM {
                if ($Summary) {
                    return @{ license_type = 'PAID'; serial_number = 'BXXXXXXXXXX' }
                }
                return @{ serialNumber = 'BXXXXXXXXXX'; seats = 10000; productName = 'Symantec Endpoint Security Complete' }
            }
        }

        It 'stores Get-SEPMGroups output in Groups property' {
            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $result.Groups | Should -Not -BeNullOrEmpty
            $result.Groups.Count | Should -Be 2
            $result.Groups[0].name | Should -Be 'My Company'
            $result.Groups[1].name | Should -Be 'Workstations'
        }

        It 'stores per-group Get-SEPMLocation output in Locations property' {
            # Use a simple mock that always returns 1 location per call to test
            Mock Get-SEPMLocation -ModuleName PSSymantecSEPM {
                return @([PSCustomObject]@{ locationName = $GroupID; locationId = 'LOC'; groupName = ''; groupId = ''; groupFullPathName = '' })
            }

            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $result.Locations | Should -Not -BeNullOrEmpty
            # 2 groups * 1 location each = 2 locations
            $result.Locations.Count | Should -Be 2
        }

        It 'stores per-group-location Get-SEPMLocationXML output in LocationXML property' {
            # Override Get-SEPMLocationXML to return XML strings
            $script:xmlCallCount = 0
            Mock Get-SEPMLocationXML -ModuleName PSSymantecSEPM {
                $script:xmlCallCount++
                return "<Location><Id>$LocationID</Id></Location>"
            }
            # Override Get-SEPMLocation to return locations with real group IDs
            Mock Get-SEPMLocation -ModuleName PSSymantecSEPM {
                if ($GroupID -eq 'GRP001') {
                    return @([PSCustomObject]@{ locationName = 'Default'; locationId = 'LOC001'; groupName = 'My Company'; groupId = 'GRP001'; groupFullPathName = 'My Company' })
                }
                return @([PSCustomObject]@{ locationName = 'Default'; locationId = 'LOC002'; groupName = 'Workstations'; groupId = 'GRP002'; groupFullPathName = 'My Company\Workstations' })
            }

            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $result.LocationXML | Should -Not -BeNullOrEmpty
            $result.LocationXML.Count | Should -Be 2
            $script:xmlCallCount | Should -Be 2
        }

        It 'stores per-group-location Get-SEPMGroupSettings output in GroupSettings property' {
            # Override Get-SEPMGroupSettings to return settings objects
            $script:settingsCallCount = 0
            Mock Get-SEPMGroupSettings -ModuleName PSSymantecSEPM {
                $script:settingsCallCount++
                return @{ groupId = $groupId; locationId = $locationId; setting = 'value' }
            }
            # Override Get-SEPMLocation to return locations with real group IDs
            Mock Get-SEPMLocation -ModuleName PSSymantecSEPM {
                if ($GroupID -eq 'GRP001') {
                    return @([PSCustomObject]@{ locationName = 'Default'; locationId = 'LOC001'; groupName = 'My Company'; groupId = 'GRP001'; groupFullPathName = 'My Company' })
                }
                return @([PSCustomObject]@{ locationName = 'Default'; locationId = 'LOC002'; groupName = 'Workstations'; groupId = 'GRP002'; groupFullPathName = 'My Company\Workstations' })
            }

            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $result.GroupSettings | Should -Not -BeNullOrEmpty
            $result.GroupSettings.Count | Should -Be 2
            $script:settingsCallCount | Should -Be 2
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

        It 'writes client & computer .clixml files' {
            Mock Get-SEPComputers -ModuleName PSSymantecSEPM {
                Write-Output @(
                    @{ computerName = 'PC-001'; group = @{ name = 'Group1' }; infected = 0 }
                ) -NoEnumerate
            }
            Mock Get-SEPClientStatus -ModuleName PSSymantecSEPM {
                Write-Output @(
                    @{ status = 'ONLINE'; clientsCount = 10 }
                ) -NoEnumerate
            }
            Mock Get-SEPClientVersion -ModuleName PSSymantecSEPM {
                Write-Output @(
                    @{ version = '14.3.510.0000'; clientsCount = 12; formattedVersion = '14.3 (14.3) build 0000' }
                ) -NoEnumerate
            }
            Mock Get-SEPClientDefVersions -ModuleName PSSymantecSEPM {
                Write-Output @(
                    @{ version = '2023-09-04 rev. 002'; clientsCount = 15 }
                ) -NoEnumerate
            }
            Mock Get-SEPClientInfectedStatus -ModuleName PSSymantecSEPM {
                Write-Output @(
                    @{ computerName = 'INFECTED-PC'; infected = 1 }
                ) -NoEnumerate
            }
            Export-SEPMInventory -OutputDir 'TestDrive:' | Out-Null
            Join-Path -Path 'TestDrive:' -ChildPath 'all_computers.xml'       | Should -Exist
            Join-Path -Path 'TestDrive:' -ChildPath 'all_client_status.xml'   | Should -Exist
            Join-Path -Path 'TestDrive:' -ChildPath 'all_client_versions.xml' | Should -Exist
            Join-Path -Path 'TestDrive:' -ChildPath 'all_client_def_versions.xml' | Should -Exist
            Join-Path -Path 'TestDrive:' -ChildPath 'all_client_infected.xml' | Should -Exist
        }

        It 'writes all_host_groups.xml when HostGroups data exists' {
            Mock Get-SEPMHostGroupSummary -ModuleName PSSymantecSEPM {
                Write-Output @(
                    [PSCustomObject]@{ id = 'HG001'; name = 'Web Servers'; domainid = 'DOM001'; lastmodifiedtime = 1700000000000 }
                ) -NoEnumerate
            }
            Mock Get-SEPMHostGroup -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ id = 'HG001'; name = 'Web Servers'; hosts = @() }
            }
            Export-SEPMInventory -OutputDir 'TestDrive:' | Out-Null
            Join-Path -Path 'TestDrive:' -ChildPath 'all_host_groups.xml' | Should -Exist
        }

        It 'writes groups & locations .clixml files' {
            Mock Get-SEPMLocationXML -ModuleName PSSymantecSEPM {
                return "<Location><Id>$LocationID</Id></Location>"
            }
            Mock Get-SEPMGroupSettings -ModuleName PSSymantecSEPM {
                return @{ groupId = $groupId; setting = 'value' }
            }
            Export-SEPMInventory -OutputDir 'TestDrive:' | Out-Null
            Join-Path -Path 'TestDrive:' -ChildPath 'all_groups.xml'           | Should -Exist
            Join-Path -Path 'TestDrive:' -ChildPath 'all_locations.xml'        | Should -Exist
            Join-Path -Path 'TestDrive:' -ChildPath 'all_location_xml.xml'     | Should -Exist
            Join-Path -Path 'TestDrive:' -ChildPath 'all_group_settings.xml'   | Should -Exist
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

        It 'captures Computers failure in Failures array' {
            Mock Get-SEPComputers -ModuleName PSSymantecSEPM { throw 'Computers API unavailable' }

            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $compFailures = $result.Failures | Where-Object { $_.Category -eq 'Computers' }
            $compFailures.Count | Should -Be 1
            $compFailures[0].Error | Should -Be 'Computers API unavailable'
        }

        It 'writes Computers_failed.xml on failure' {
            Mock Get-SEPComputers -ModuleName PSSymantecSEPM { throw 'Computers API error' }

            Get-ChildItem -Path 'TestDrive:' -Filter '*_failed.xml' | Remove-Item -Force -ErrorAction SilentlyContinue
            Export-SEPMInventory -OutputDir 'TestDrive:' | Out-Null
            Join-Path -Path 'TestDrive:' -ChildPath 'Computers_failed.xml' | Should -Exist
        }

        It 'captures ClientStatus failure in Failures array' {
            Mock Get-SEPClientStatus -ModuleName PSSymantecSEPM { throw 'ClientStatus API unavailable' }

            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $csFailures = $result.Failures | Where-Object { $_.Category -eq 'ClientStatus' }
            $csFailures.Count | Should -Be 1
            $csFailures[0].Error | Should -Be 'ClientStatus API unavailable'
        }

        It 'captures ClientVersions failure in Failures array' {
            Mock Get-SEPClientVersion -ModuleName PSSymantecSEPM { throw 'ClientVersions API unavailable' }

            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $cvFailures = $result.Failures | Where-Object { $_.Category -eq 'ClientVersions' }
            $cvFailures.Count | Should -Be 1
            $cvFailures[0].Error | Should -Be 'ClientVersions API unavailable'
        }

        It 'captures ClientDefVersions failure in Failures array' {
            Mock Get-SEPClientDefVersions -ModuleName PSSymantecSEPM { throw 'ClientDefVersions API unavailable' }

            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $cdvFailures = $result.Failures | Where-Object { $_.Category -eq 'ClientDefVersions' }
            $cdvFailures.Count | Should -Be 1
            $cdvFailures[0].Error | Should -Be 'ClientDefVersions API unavailable'
        }

        It 'captures ClientInfected failure in Failures array' {
            Mock Get-SEPClientInfectedStatus -ModuleName PSSymantecSEPM { throw 'ClientInfected API unavailable' }

            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $ciFailures = $result.Failures | Where-Object { $_.Category -eq 'ClientInfected' }
            $ciFailures.Count | Should -Be 1
            $ciFailures[0].Error | Should -Be 'ClientInfected API unavailable'
        }

        It 'captures Groups failure in Failures array' {
            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM { throw 'Groups API unavailable' }

            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $gFailures = $result.Failures | Where-Object { $_.Category -eq 'Groups' }
            $gFailures.Count | Should -Be 1
            $gFailures[0].Error | Should -Be 'Groups API unavailable'
            $result.Groups | Should -BeNullOrEmpty
        }

        It 'writes Groups_failed.xml on failure' {
            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM { throw 'Groups API error' }

            Get-ChildItem -Path 'TestDrive:' -Filter '*_failed.xml' | Remove-Item -Force -ErrorAction SilentlyContinue
            Export-SEPMInventory -OutputDir 'TestDrive:' | Out-Null
            Join-Path -Path 'TestDrive:' -ChildPath 'Groups_failed.xml' | Should -Exist
        }

        It 'captures Locations failure in Failures array' {
            Mock Get-SEPMLocation -ModuleName PSSymantecSEPM { throw 'Locations API unavailable' }

            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $locFailures = $result.Failures | Where-Object { $_.Category -eq 'Locations' }
            $locFailures.Count | Should -Be 2
            $locFailures[0].Error | Should -Be 'Locations API unavailable'
        }

        It 'writes Locations_failed.xml on failure' {
            Mock Get-SEPMLocation -ModuleName PSSymantecSEPM { throw 'Locations API error' }

            Get-ChildItem -Path 'TestDrive:' -Filter '*_failed.xml' | Remove-Item -Force -ErrorAction SilentlyContinue
            Export-SEPMInventory -OutputDir 'TestDrive:' | Out-Null
            Join-Path -Path 'TestDrive:' -ChildPath 'Locations_failed.xml' | Should -Exist
        }

        It 'captures LocationXML failure in Failures array' {
            Mock Get-SEPMLocationXML -ModuleName PSSymantecSEPM { throw 'LocationXML API unavailable' }

            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $xmlFailures = $result.Failures | Where-Object { $_.Category -eq 'LocationXML' }
            $xmlFailures.Count | Should -Be 2
            $xmlFailures[0].Error | Should -Be 'LocationXML API unavailable'
        }

        It 'writes LocationXML_failed.xml on failure' {
            Mock Get-SEPMLocationXML -ModuleName PSSymantecSEPM { throw 'LocationXML API error' }

            Get-ChildItem -Path 'TestDrive:' -Filter '*_failed.xml' | Remove-Item -Force -ErrorAction SilentlyContinue
            Export-SEPMInventory -OutputDir 'TestDrive:' | Out-Null
            Join-Path -Path 'TestDrive:' -ChildPath 'LocationXML_failed.xml' | Should -Exist
        }

        It 'captures HostGroups summary failure in Failures array' {
            Mock Get-SEPMHostGroupSummary -ModuleName PSSymantecSEPM { throw 'HostGroups API unavailable' }

            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $hgFailures = $result.Failures | Where-Object { $_.Category -eq 'HostGroups' }
            $hgFailures.Count | Should -Be 1
            $hgFailures[0].Error | Should -Be 'HostGroups API unavailable'
        }

        It 'writes HostGroups_failed.xml on summary failure' {
            Mock Get-SEPMHostGroupSummary -ModuleName PSSymantecSEPM { throw 'HostGroups API error' }

            Get-ChildItem -Path 'TestDrive:' -Filter '*_failed.xml' | Remove-Item -Force -ErrorAction SilentlyContinue
            Export-SEPMInventory -OutputDir 'TestDrive:' | Out-Null
            Join-Path -Path 'TestDrive:' -ChildPath 'HostGroups_failed.xml' | Should -Exist
        }

        It 'captures per-host-group failure and continues with remaining Host Groups' {
            Mock Get-SEPMHostGroupSummary -ModuleName PSSymantecSEPM {
                Write-Output @(
                    [PSCustomObject]@{ id = 'HG001'; name = 'Working HG'; domainid = 'DOM001'; lastmodifiedtime = 1700000000000 }
                    [PSCustomObject]@{ id = 'HG002'; name = 'Failing HG'; domainid = 'DOM001'; lastmodifiedtime = 1700000000001 }
                    [PSCustomObject]@{ id = 'HG003'; name = 'Another HG'; domainid = 'DOM001'; lastmodifiedtime = 1700000000002 }
                ) -NoEnumerate
            }
            $script:hgFailCallCount = 0
            Mock Get-SEPMHostGroup -ModuleName PSSymantecSEPM {
                $script:hgFailCallCount++
                if ($Id -eq 'HG002') { throw 'Host Group API error' }
                return [PSCustomObject]@{ id = $Id; name = 'Host Group Detail'; hosts = @(@{ mac = '00:11:22:33:44:55' }) }
            }

            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $hgFailures = $result.Failures | Where-Object { $_.Category -eq 'HostGroups' }
            $hgFailures.Count | Should -Be 1
            $hgFailures[0].HostGroupName | Should -Be 'Failing HG'
            $hgFailures[0].HostGroupID | Should -Be 'HG002'
            $result.HostGroups.Count | Should -Be 2
            $result.HostGroups[0].id | Should -Be 'HG001'
            $result.HostGroups[1].id | Should -Be 'HG003'
            $script:hgFailCallCount | Should -Be 3
        }

        It 'writes HostGroups_failed.xml on per-Host-Group failure' {
            Mock Get-SEPMHostGroupSummary -ModuleName PSSymantecSEPM {
                Write-Output @(
                    [PSCustomObject]@{ id = 'HG001'; name = 'Failing HG'; domainid = 'DOM001'; lastmodifiedtime = 1700000000000 }
                ) -NoEnumerate
            }
            Mock Get-SEPMHostGroup -ModuleName PSSymantecSEPM { throw 'Host Group error' }

            Get-ChildItem -Path 'TestDrive:' -Filter '*_failed.xml' | Remove-Item -Force -ErrorAction SilentlyContinue
            Export-SEPMInventory -OutputDir 'TestDrive:' | Out-Null
            Join-Path -Path 'TestDrive:' -ChildPath 'HostGroups_failed.xml' | Should -Exist
        }

        It 'captures GroupSettings failure in Failures array' {
            Mock Get-SEPMGroupSettings -ModuleName PSSymantecSEPM { throw 'GroupSettings API unavailable' }

            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $gsFailures = $result.Failures | Where-Object { $_.Category -eq 'GroupSettings' }
            $gsFailures.Count | Should -Be 2
            $gsFailures[0].Error | Should -Be 'GroupSettings API unavailable'
        }

        It 'writes GroupSettings_failed.xml on failure' {
            Mock Get-SEPMGroupSettings -ModuleName PSSymantecSEPM { throw 'GroupSettings API error' }

            Get-ChildItem -Path 'TestDrive:' -Filter '*_failed.xml' | Remove-Item -Force -ErrorAction SilentlyContinue
            Export-SEPMInventory -OutputDir 'TestDrive:' | Out-Null
            Join-Path -Path 'TestDrive:' -ChildPath 'GroupSettings_failed.xml' | Should -Exist
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

    Context 'Progress bar' {
        BeforeAll {
            Mock Get-SEPMLicense -ModuleName PSSymantecSEPM {
                if ($Summary) {
                    return @{ license_type = 'PAID'; serial_number = 'BXXXXXXXXXX' }
                }
                return @{ serialNumber = 'BXXXXXXXXXX'; seats = 10000; productName = 'Symantec Endpoint Security Complete' }
            }

            $script:progressCalls = @()
            Mock Write-Progress -ModuleName PSSymantecSEPM {
                $script:progressCalls += @{
                    Activity = $Activity
                    Status = $Status
                    PercentComplete = $PercentComplete
                }
            }
        }

        It 'calls Write-Progress exactly 25 times' {
            $script:progressCalls = @()
            Export-SEPMInventory -OutputDir 'TestDrive:' | Out-Null
            $script:progressCalls.Count | Should -Be 25
        }

        It 'all calls have Activity set to Export-SEPMInventory' {
            $script:progressCalls = @()
            Export-SEPMInventory -OutputDir 'TestDrive:' | Out-Null
            $script:progressCalls | ForEach-Object { $_.Activity | Should -Be 'Export-SEPMInventory' }
        }

        It 'Status format matches [N/25] CategoryName for all calls' {
            $script:progressCalls = @()
            Export-SEPMInventory -OutputDir 'TestDrive:' | Out-Null
            for ($i = 0; $i -lt 25; $i++) {
                $script:progressCalls[$i].Status | Should -Match '^\[\d+/25\] \w+$'
            }
        }

        It 'Status starts at [1/25] and ends at [25/25]' {
            $script:progressCalls = @()
            Export-SEPMInventory -OutputDir 'TestDrive:' | Out-Null
            $script:progressCalls[0].Status | Should -Match '^\[1/25\]'
            $script:progressCalls[24].Status | Should -Match '^\[25/25\]'
        }

        It 'PercentComplete increases from 0 to 100' {
            $script:progressCalls = @()
            Export-SEPMInventory -OutputDir 'TestDrive:' | Out-Null
            $script:progressCalls[0].PercentComplete | Should -Be 4
            $script:progressCalls[24].PercentComplete | Should -Be 100
            # Verify monotonic increase
            for ($i = 1; $i -lt 25; $i++) {
                $script:progressCalls[$i].PercentComplete | Should -BeGreaterThan $script:progressCalls[$i-1].PercentComplete
            }
        }
    }

    Context 'Verbose output' {
        BeforeAll {
            Mock Get-SEPMLicense -ModuleName PSSymantecSEPM {
                if ($Summary) {
                    return @{ license_type = 'PAID'; serial_number = 'BXXXXXXXXXX' }
                }
                return @{ serialNumber = 'BXXXXXXXXXX'; seats = 10000; productName = 'Symantec Endpoint Security Complete' }
            }
        }

        It 'emits exactly 25 category-level Write-Verbose messages' {
            $verboseMsgs = [System.Collections.Generic.List[string]]::new()
            $null = Export-SEPMInventory -OutputDir 'TestDrive:' -Verbose *>&1 | ForEach-Object {
                if ($_ -is [System.Management.Automation.VerboseRecord]) {
                    $verboseMsgs.Add($_.Message)
                }
            }
            $verboseMsgs.Count | Should -Be 25
        }

        It 'each verbose line has timestamp, elapsed, step counter, category, status, metric, and duration' {
            $verboseMsgs = [System.Collections.Generic.List[string]]::new()
            $null = Export-SEPMInventory -OutputDir 'TestDrive:' -Verbose *>&1 | ForEach-Object {
                if ($_ -is [System.Management.Automation.VerboseRecord]) {
                    $verboseMsgs.Add($_.Message)
                }
            }

            foreach ($msg in $verboseMsgs) {
                # Check each format component separately
                $msg | Should -Match '^\[\d{2}:\d{2}:\d{2}\]'          # Timestamp [HH:mm:ss]
                $msg | Should -Match '\[\+\d+s\]'                        # Elapsed [+SSs]
                $msg | Should -Match '\[\d{2}/25\]'                      # Step counter [NN/25]
                $msg | Should -Match '\s(OK|OK \(empty\)|FAILED)\s'     # Status
                $msg | Should -Match '\(\d+ms\)'                         # Duration (Nms)
            }
        }

        It 'shows OK status with version metric for Version category' {
            $verboseMsgs = [System.Collections.Generic.List[string]]::new()
            $null = Export-SEPMInventory -OutputDir 'TestDrive:' -Verbose *>&1 | ForEach-Object {
                if ($_ -is [System.Management.Automation.VerboseRecord]) {
                    $verboseMsgs.Add($_.Message)
                }
            }

            # First message should be Version with OK status and version string
            $verboseMsgs[0] | Should -Match '\bVersion\b.*\bOK\b'
            $verboseMsgs[0] | Should -Match '\b14\.3\.9816\.7000\b'
        }

        It 'shows OK (empty) for a category with empty results' {
            # PolicySummaries mock returns empty array by default
            $verboseMsgs = [System.Collections.Generic.List[string]]::new()
            $null = Export-SEPMInventory -OutputDir 'TestDrive:' -Verbose *>&1 | ForEach-Object {
                if ($_ -is [System.Management.Automation.VerboseRecord]) {
                    $verboseMsgs.Add($_.Message)
                }
            }

            # PolicySummaries is step 12 (0-indexed: 11)
            $verboseMsgs[11] | Should -Match 'PolicySummaries.*OK \(empty\)'
        }

        It 'shows FAILED status for a category that throws an exception' {
            Mock Get-SEPMVersion -ModuleName PSSymantecSEPM { throw 'Version API unavailable' }

            $verboseMsgs = [System.Collections.Generic.List[string]]::new()
            $null = Export-SEPMInventory -OutputDir 'TestDrive:' -Verbose *>&1 | ForEach-Object {
                if ($_ -is [System.Management.Automation.VerboseRecord]) {
                    $verboseMsgs.Add($_.Message)
                }
            }

            $verboseMsgs[0] | Should -Match 'Version.*FAILED'
        }

        It 'shows OK (empty) for Locations when no groups exist' {
            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM {
                Write-Output @() -NoEnumerate
            }

            $verboseMsgs = [System.Collections.Generic.List[string]]::new()
            $null = Export-SEPMInventory -OutputDir 'TestDrive:' -Verbose *>&1 | ForEach-Object {
                if ($_ -is [System.Management.Automation.VerboseRecord]) {
                    $verboseMsgs.Add($_.Message)
                }
            }

            # Locations is step 22 (0-indexed: 21)
            $verboseMsgs[21] | Should -Match 'Locations.*OK \(empty\)'
        }
    }

    Context 'Heartbeat verbose output' {
        BeforeAll {
            Mock Get-SEPMLicense -ModuleName PSSymantecSEPM {
                if ($Summary) {
                    return @{ license_type = 'PAID'; serial_number = 'BXXXXXXXXXX' }
                }
                return @{ serialNumber = 'BXXXXXXXXXX'; seats = 10000; productName = 'Symantec Endpoint Security Complete' }
            }
        }

        It 'emits heartbeat lines at expected interval when HostGroups has >10 items' {
            $hgItems = 1..60 | ForEach-Object {
                [PSCustomObject]@{ id = "HG$([String]$_).PadLeft(3,'0')"; name = "Host Group $_"; domainid = 'DOM001'; lastmodifiedtime = 1700000000000 }
            }
            Mock Get-SEPMHostGroupSummary -ModuleName PSSymantecSEPM {
                Write-Output $hgItems -NoEnumerate
            }
            Mock Get-SEPMHostGroup -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ id = $Id; name = 'Detail'; hosts = @() }
            }
            # Suppress heartbeat collisions from other fan-out categories
            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM { Write-Output @() -NoEnumerate }
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM { Write-Output @() -NoEnumerate }

            $verboseMsgs = [System.Collections.Generic.List[string]]::new()
            $null = Export-SEPMInventory -OutputDir 'TestDrive:' -Verbose *>&1 | ForEach-Object {
                if ($_ -is [System.Management.Automation.VerboseRecord]) {
                    $verboseMsgs.Add($_.Message)
                }
            }

            # Filter heartbeat lines
            $heartbeats = $verboseMsgs | Where-Object { $_ -match '^  →' }
            # With 60 items, interval = max(10, floor(60/10)) = max(10, 6) = 10
            # Heartbeats at 10, 20, 30, 40, 50, 60 = 6 heartbeats
            $heartbeats.Count | Should -Be 6
        }

        It 'heartbeat lines follow "  → N/total ContextName" format' {
            $hgItems = 1..60 | ForEach-Object {
                [PSCustomObject]@{ id = "HG$([String]$_).PadLeft(3,'0')"; name = "Host Group $_"; domainid = 'DOM001'; lastmodifiedtime = 1700000000000 }
            }
            Mock Get-SEPMHostGroupSummary -ModuleName PSSymantecSEPM {
                Write-Output $hgItems -NoEnumerate
            }
            Mock Get-SEPMHostGroup -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ id = $Id; name = 'Detail'; hosts = @() }
            }
            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM { Write-Output @() -NoEnumerate }
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM { Write-Output @() -NoEnumerate }

            $verboseMsgs = [System.Collections.Generic.List[string]]::new()
            $null = Export-SEPMInventory -OutputDir 'TestDrive:' -Verbose *>&1 | ForEach-Object {
                if ($_ -is [System.Management.Automation.VerboseRecord]) {
                    $verboseMsgs.Add($_.Message)
                }
            }

            $heartbeats = $verboseMsgs | Where-Object { $_ -match '^  →' }
            foreach ($hb in $heartbeats) {
                $hb | Should -Match '^  → group \d+/60 '  # Format: "  → group N/60 Name"
            }
            # First heartbeat at 10/60
            $heartbeats[0] | Should -Match '  → group 10/60 '
        }

        It 'no heartbeat lines when fan-out has ≤10 items' {
            # With 2 groups, Locations has 2 items → interval = max(10, 0) = 10 → no heartbeats
            # Default mock has 2 groups

            $verboseMsgs = [System.Collections.Generic.List[string]]::new()
            $null = Export-SEPMInventory -OutputDir 'TestDrive:' -Verbose *>&1 | ForEach-Object {
                if ($_ -is [System.Management.Automation.VerboseRecord]) {
                    $verboseMsgs.Add($_.Message)
                }
            }

            $heartbeats = $verboseMsgs | Where-Object { $_ -match '^  →' }
            $heartbeats.Count | Should -Be 0
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
