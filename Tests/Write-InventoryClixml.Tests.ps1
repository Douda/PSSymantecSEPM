[CmdletBinding()]
param()

Describe 'Write-InventoryClixml' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Basic functionality' {
        It 'writes a single category file from a snapshot property' {
            InModuleScope PSSymantecSEPM {
                $snapshot = [PSCustomObject]@{
                    FetchedAt = [DateTime]::UtcNow
                    Version   = @{ version = '14.3' }
                    Failures  = @()
                }
                $snapshot.PSObject.TypeNames.Insert(0, 'SEPM.Inventory')

                Write-InventoryClixml -Snapshot $snapshot -OutputDir 'TestDrive:'

                $path = Join-Path -Path 'TestDrive:' -ChildPath 'all_version.xml'
                Test-Path -Path $path | Should -BeTrue

                $imported = Import-Clixml -Path $path
                $imported.version | Should -Be '14.3'
            }
        }
    }

    Context 'Null and empty handling' {
        It 'skips null properties' {
            InModuleScope PSSymantecSEPM {
                $snapshot = [PSCustomObject]@{
                    FetchedAt = [DateTime]::UtcNow
                    Version   = $null
                    Domains   = @{ name = 'Default' }
                    Failures  = @()
                }
                $snapshot.PSObject.TypeNames.Insert(0, 'SEPM.Inventory')

                Write-InventoryClixml -Snapshot $snapshot -OutputDir 'TestDrive:'

                # Domains should be written
                Join-Path -Path 'TestDrive:' -ChildPath 'all_domains.xml' | Should -Exist
                # Version is null — should NOT be written
                Join-Path -Path 'TestDrive:' -ChildPath 'all_version.xml' | Should -Not -Exist
            }
        }

        It 'skips empty arrays' {
            InModuleScope PSSymantecSEPM {
                $snapshot = [PSCustomObject]@{
                    FetchedAt = [DateTime]::UtcNow
                    GUPs      = @()
                    Domains   = @{ name = 'Default' }
                    Failures  = @()
                }
                $snapshot.PSObject.TypeNames.Insert(0, 'SEPM.Inventory')

                Write-InventoryClixml -Snapshot $snapshot -OutputDir 'TestDrive:'

                # Domains should be written
                Join-Path -Path 'TestDrive:' -ChildPath 'all_domains.xml' | Should -Exist
                # GUPs is empty array — should NOT be written
                Join-Path -Path 'TestDrive:' -ChildPath 'all_gups.xml' | Should -Not -Exist
            }
        }
    }

    Context 'Metadata properties' {
        It 'does not write FetchedAt or Failures as separate files' {
            InModuleScope PSSymantecSEPM {
                $snapshot = [PSCustomObject]@{
                    FetchedAt = [DateTime]::UtcNow
                    Version   = @{ version = '14.3' }
                    Failures  = @(
                        [PSCustomObject]@{ Category = 'Test'; Error = 'error' }
                    )
                }
                $snapshot.PSObject.TypeNames.Insert(0, 'SEPM.Inventory')

                Write-InventoryClixml -Snapshot $snapshot -OutputDir 'TestDrive:'

                # No metadata file should exist
                Join-Path -Path 'TestDrive:' -ChildPath 'all_fetched_at.xml' | Should -Not -Exist
                Join-Path -Path 'TestDrive:' -ChildPath 'all_failures.xml' | Should -Not -Exist
            }
        }
    }

    Context 'CamelCase to snake_case conversion' {
        It 'converts ClientDefVersions to all_client_def_versions.xml' {
            InModuleScope PSSymantecSEPM {
                $snapshot = [PSCustomObject]@{
                    FetchedAt        = [DateTime]::UtcNow
                    ClientDefVersions = @(
                        @{ version = '2023-09-04 rev. 002'; clientsCount = 15 }
                    )
                    Failures         = @()
                }
                $snapshot.PSObject.TypeNames.Insert(0, 'SEPM.Inventory')

                Write-InventoryClixml -Snapshot $snapshot -OutputDir 'TestDrive:'

                $path = Join-Path -Path 'TestDrive:' -ChildPath 'all_client_def_versions.xml'
                Test-Path -Path $path | Should -BeTrue
            }
        }

        It 'converts FirewallPolicies to all_firewall_policies.xml' {
            InModuleScope PSSymantecSEPM {
                $snapshot = [PSCustomObject]@{
                    FetchedAt       = [DateTime]::UtcNow
                    FirewallPolicies = @(
                        @{ name = 'Default Firewall Policy' }
                    )
                    Failures        = @()
                }
                $snapshot.PSObject.TypeNames.Insert(0, 'SEPM.Inventory')

                Write-InventoryClixml -Snapshot $snapshot -OutputDir 'TestDrive:'

                $path = Join-Path -Path 'TestDrive:' -ChildPath 'all_firewall_policies.xml'
                Test-Path -Path $path | Should -BeTrue
            }
        }

        It 'converts LocationXML to all_location_xml.xml' {
            InModuleScope PSSymantecSEPM {
                $snapshot = [PSCustomObject]@{
                    FetchedAt   = [DateTime]::UtcNow
                    LocationXML = @(
                        '<Location><Id>LOC001</Id></Location>'
                    )
                    Failures    = @()
                }
                $snapshot.PSObject.TypeNames.Insert(0, 'SEPM.Inventory')

                Write-InventoryClixml -Snapshot $snapshot -OutputDir 'TestDrive:'

                $path = Join-Path -Path 'TestDrive:' -ChildPath 'all_location_xml.xml'
                Test-Path -Path $path | Should -BeTrue
            }
        }

        It 'converts all 25 category names correctly' {
            InModuleScope PSSymantecSEPM {
                $snapshot = [PSCustomObject]@{
                    FetchedAt          = [DateTime]::UtcNow
                    Version            = @{ v = '1' }
                    Domains            = @{ v = '1' }
                    GUPs               = @{ v = '1' }
                    Admins             = @{ v = '1' }
                    DatabaseInfo       = @{ v = '1' }
                    License            = @{ v = '1' }
                    LicenseSummary     = @{ v = '1' }
                    ReplicationStatus  = @{ v = '1' }
                    ThreatStats        = @{ v = '1' }
                    LatestDefinitions  = @{ v = '1' }
                    Events             = @{ v = '1' }
                    PolicySummaries    = @{ v = '1' }
                    FirewallPolicies   = @{ v = '1' }
                    IpsPolicies        = @{ v = '1' }
                    ExceptionPolicies  = @{ v = '1' }
                    Computers          = @{ v = '1' }
                    ClientStatus       = @{ v = '1' }
                    ClientVersions     = @{ v = '1' }
                    ClientDefVersions  = @{ v = '1' }
                    ClientInfected     = @{ v = '1' }
                    Groups             = @{ v = '1' }
                    Locations          = @{ v = '1' }
                    LocationXML        = @{ v = '1' }
                    GroupSettings      = @{ v = '1' }
                    HostGroups         = @{ v = '1' }
                    Failures           = @()
                }
                $snapshot.PSObject.TypeNames.Insert(0, 'SEPM.Inventory')

                Write-InventoryClixml -Snapshot $snapshot -OutputDir 'TestDrive:'

                # All 25 categories should produce files
                $expectedFiles = @(
                    'all_version.xml'
                    'all_domains.xml'
                    'all_gups.xml'
                    'all_admins.xml'
                    'all_database_info.xml'
                    'all_license.xml'
                    'all_license_summary.xml'
                    'all_replication_status.xml'
                    'all_threat_stats.xml'
                    'all_latest_definitions.xml'
                    'all_events.xml'
                    'all_policy_summaries.xml'
                    'all_firewall_policies.xml'
                    'all_ips_policies.xml'
                    'all_exception_policies.xml'
                    'all_computers.xml'
                    'all_client_status.xml'
                    'all_client_versions.xml'
                    'all_client_def_versions.xml'
                    'all_client_infected.xml'
                    'all_groups.xml'
                    'all_locations.xml'
                    'all_location_xml.xml'
                    'all_group_settings.xml'
                    'all_host_groups.xml'
                )

                foreach ($file in $expectedFiles) {
                    $path = Join-Path -Path 'TestDrive:' -ChildPath $file
                    if (-not (Test-Path -Path $path)) {
                        throw "Expected file not found: $file"
                    }
                }
            }
        }
    }

    Context 'Timestamped blob' {
        It 'writes a timestamped .clixml blob with correct filename pattern' {
            InModuleScope PSSymantecSEPM {
                $snapshot = [PSCustomObject]@{
                    FetchedAt = [DateTime]::UtcNow
                    Version   = @{ version = '14.3' }
                    Failures  = @()
                }
                $snapshot.PSObject.TypeNames.Insert(0, 'SEPM.Inventory')

                Write-InventoryClixml -Snapshot $snapshot -OutputDir 'TestDrive:'

                $blobs = Get-ChildItem -Path 'TestDrive:' -Filter 'SepmInventory_*.clixml'
                $blobs.Count | Should -BeGreaterThan 0
                $blobs[0].Name | Should -Match '^SepmInventory_\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}\.clixml$'
            }
        }
    }
}
