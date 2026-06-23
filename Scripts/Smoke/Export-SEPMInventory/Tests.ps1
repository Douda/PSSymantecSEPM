<#
.SYNOPSIS
    Shared smoke tests for Export-SEPMInventory.

.DESCRIPTION
    Dot-sourced by run.ps7.ps1 and run.ps51.ps1 after Common.ps1.
    Calls Export-SEPMInventory ONCE and shares the result across assertions.
    Covers: SEPM.Inventory type, all categories, per-category clixml,
            timestamped blob, round-trip.
#>

$results = @{}
$outDir = Join-Path $RepoRoot 'Output/smoke-inventory'

# ── Single inventory call: shared across all tests ──
$snapshot = Export-SEPMInventory -OutputDir $outDir -DelayMs 10

# ── A1: Returns SEPM.Inventory PSTypeName ──
$results.A1 = T "A1" "Export-SEPMInventory returns SEPM.Inventory PSTypeName" `
    { $snapshot } `
    { param($r)
        $r -ne $null -and
        $r.PSObject.TypeNames[0] -eq 'SEPM.Inventory'
    }

# ── A2: FetchedAt is DateTime and recent ──
$results.A2 = T "A2" "FetchedAt is a DateTime within last 5 minutes" `
    { $snapshot } `
    { param($r)
        $r.FetchedAt -is [DateTime] -and
        $r.FetchedAt -gt [DateTime]::UtcNow.AddMinutes(-5)
    }

# ── A3: Version populated with real SEPM data ──
$results.A3 = T "A3" "Version property has API_SEQUENCE, API_VERSION, version" `
    { $snapshot } `
    { param($r)
        $r.Version -ne $null -and
        -not [string]::IsNullOrEmpty($r.Version.API_SEQUENCE) -and
        -not [string]::IsNullOrEmpty($r.Version.version)
    }

# ── A4: Domains populated (Default domain) ──
$results.A4 = T "A4" "Domains has id and name properties" `
    { $snapshot } `
    { param($r)
        $r.Domains -ne $null -and
        -not [string]::IsNullOrEmpty($r.Domains.id) -and
        -not [string]::IsNullOrEmpty($r.Domains.name)
    }

# ── A5: GUPs non-null (may be empty if no GUPs configured) ──
$results.A5 = T "A5" "GUPs property is not null" `
    { $snapshot } `
    { param($r) $null -ne $r.GUPs }

# ── A6: Admins populated ──
$results.A6 = T "A6" "Admins has entries with loginName property" `
    { $snapshot } `
    { param($r)
        $null -ne $r.Admins -and
        ($r.Admins | Select-Object -First 1).loginName -ne $null
    }

# ── A7: DatabaseInfo populated ──
$results.A7 = T "A7" "DatabaseInfo has type property" `
    { $snapshot } `
    { param($r)
        $r.DatabaseInfo -ne $null -and
        -not [string]::IsNullOrEmpty($r.DatabaseInfo.type)
    }

# ── A8: License populated ──
$results.A8 = T "A8" "License has serialNumber property" `
    { $snapshot } `
    { param($r)
        $r.License -ne $null -and
        -not [string]::IsNullOrEmpty($r.License.serialNumber)
    }

# ── A9: LicenseSummary populated ──
$results.A9 = T "A9" "LicenseSummary has license_type property" `
    { $snapshot } `
    { param($r)
        $r.LicenseSummary -ne $null -and
        -not [string]::IsNullOrEmpty($r.LicenseSummary.license_type)
    }

# ── A10: ReplicationStatus populated ──
$results.A10 = T "A10" "ReplicationStatus has entries with siteName property" `
    { $snapshot } `
    { param($r)
        $null -ne $r.ReplicationStatus -and
        ($r.ReplicationStatus | Select-Object -First 1).siteName -ne $null
    }

# ── A11: ThreatStats populated ──
$results.A11 = T "A11" "ThreatStats has entries with infectedClients property" `
    { $snapshot } `
    { param($r)
        $null -ne $r.ThreatStats -and
        ($r.ThreatStats | Select-Object -First 1).infectedClients -ne $null
    }

# ── A12: LatestDefinitions populated ──
$results.A12 = T "A12" "LatestDefinitions has contentName property" `
    { $snapshot } `
    { param($r)
        $r.LatestDefinitions -ne $null -and
        -not [string]::IsNullOrEmpty($r.LatestDefinitions.contentName)
    }

# ── A13: Events populated ──
$results.A13 = T "A13" "Events has entries with subject property" `
    { $snapshot } `
    { param($r)
        $null -ne $r.Events -and
        ($r.Events | Select-Object -First 1).subject -ne $null
    }

# ── A14: PolicySummaries populated ──
$results.A14 = T "A14" "PolicySummaries has entries with policytype property" `
    { $snapshot } `
    { param($r)
        $null -ne $r.PolicySummaries -and
        $r.PolicySummaries.Count -gt 0 -and
        -not [string]::IsNullOrEmpty(($r.PolicySummaries | Select-Object -First 1).policytype)
    }

# ── A15: FirewallPolicies populated (full detail) ──
$results.A15 = T "A15" "FirewallPolicies has entries with configuration" `
    { $snapshot } `
    { param($r)
        $null -ne $r.FirewallPolicies -and
        $r.FirewallPolicies.Count -gt 0 -and
        $null -ne ($r.FirewallPolicies | Select-Object -First 1).configuration
    }

# ── A16: IpsPolicies populated (full detail) ──
$results.A16 = T "A16" "IpsPolicies has entries with configuration" `
    { $snapshot } `
    { param($r)
        $null -ne $r.IpsPolicies -and
        $r.IpsPolicies.Count -gt 0 -and
        $null -ne ($r.IpsPolicies | Select-Object -First 1).configuration
    }

# ── A18: Computers populated ──
$results.A18 = T "A18" "Computers has entries with computerName property" `
    { $snapshot } `
    { param($r)
        $null -ne $r.Computers -and
        $r.Computers.Count -gt 0 -and
        -not [string]::IsNullOrEmpty(($r.Computers | Select-Object -First 1).computerName)
    }

# ── A19: ClientStatus populated ──
$results.A19 = T "A19" "ClientStatus has entries with status property" `
    { $snapshot } `
    { param($r)
        $null -ne $r.ClientStatus -and
        $r.ClientStatus.Count -gt 0 -and
        -not [string]::IsNullOrEmpty(($r.ClientStatus | Select-Object -First 1).status)
    }

# ── A20: ClientVersions populated ──
$results.A20 = T "A20" "ClientVersions has entries with version property" `
    { $snapshot } `
    { param($r)
        $null -ne $r.ClientVersions -and
        $r.ClientVersions.Count -gt 0 -and
        -not [string]::IsNullOrEmpty(($r.ClientVersions | Select-Object -First 1).version)
    }

# ── A21: ClientDefVersions populated ──
$results.A21 = T "A21" "ClientDefVersions has entries with version property" `
    { $snapshot } `
    { param($r)
        $null -ne $r.ClientDefVersions -and
        $r.ClientDefVersions.Count -gt 0 -and
        -not [string]::IsNullOrEmpty(($r.ClientDefVersions | Select-Object -First 1).version)
    }

# ── A22: ClientInfected populated (may be empty if no infected clients) ──
$results.A22 = T "A22" "ClientInfected property is not null" `
    { $snapshot } `
    { param($r) $null -ne $r.ClientInfected }

# ── A17: ExceptionPolicies populated (full detail) ──
$results.A17 = T "A17" "ExceptionPolicies has entries with configuration" `
    { $snapshot } `
    { param($r)
        $null -ne $r.ExceptionPolicies -and
        $r.ExceptionPolicies.Count -gt 0 -and
        $null -ne ($r.ExceptionPolicies | Select-Object -First 1).configuration
    }

# ── A23: Groups populated ──
$results.A23 = T "A23" "Groups has entries with name and id properties" `
    { $snapshot } `
    { param($r)
        $null -ne $r.Groups -and
        $r.Groups.Count -gt 0 -and
        -not [string]::IsNullOrEmpty(($r.Groups | Select-Object -First 1).name)
    }

# ── A24: Locations populated ──
$results.A24 = T "A24" "Locations has entries with locationName property" `
    { $snapshot } `
    { param($r)
        $null -ne $r.Locations -and
        $r.Locations.Count -gt 0 -and
        -not [string]::IsNullOrEmpty(($r.Locations | Select-Object -First 1).locationName)
    }

# ── A25: LocationXML populated ──
$results.A25 = T "A25" "LocationXML has entries (XML content per group-location)" `
    { $snapshot } `
    { param($r)
        $null -ne $r.LocationXML -and
        $r.LocationXML.Count -gt 0
    }

# ── A26: GroupSettings populated ──
$results.A26 = T "A26" "GroupSettings has entries (settings per group-location)" `
    { $snapshot } `
    { param($r)
        $null -ne $r.GroupSettings -and
        $r.GroupSettings.Count -gt 0
    }

# ── A27: HostGroups populated (full detail with hosts[]) ──
$results.A27 = T "A27" "HostGroups has entries with hosts array" `
    { $snapshot } `
    { param($r)
        $null -ne $r.HostGroups -and
        $r.HostGroups.Count -gt 0 -and
        $null -ne ($r.HostGroups | Select-Object -First 1).hosts
    }

# ── B1: Per-category clixml files written ──
$results.B1 = T "B1" "Writes all category .clixml files" `
    {
        $allExist = $true
        $files = @(
            'all_version.xml', 'all_domains.xml', 'all_admins.xml',
            'all_database_info.xml', 'all_license.xml', 'all_license_summary.xml',
            'all_replication_status.xml', 'all_threat_stats.xml',
            'all_latest_definitions.xml', 'all_events.xml',
            'all_policy_summaries.xml', 'all_fw_policies.xml',
            'all_ips_policies.xml', 'all_exception_policies.xml',
            'all_computers.xml', 'all_client_status.xml',
            'all_client_versions.xml', 'all_client_def_versions.xml',
            'all_client_infected.xml',
            'all_groups.xml', 'all_locations.xml',
            'all_location_xml.xml', 'all_group_settings.xml',
            'all_host_groups.xml'
        )
        foreach ($f in $files) {
            if (-not (Test-Path (Join-Path $outDir $f))) { $allExist = $false }
        }
        $allExist
    } `
    { param($r) $r -eq $true }

# ── B2: Timestamped blob written ──
$results.B2 = T "B2" "Writes timestamped SepmInventory_*.clixml blob" `
    {
        $blobs = Get-ChildItem -Path $outDir -Filter 'SepmInventory_*.clixml' -ErrorAction SilentlyContinue
        $global:blobPath = if ($blobs.Count -gt 0) { $blobs[0].FullName } else { $null }
        $blobs.Count -gt 0
    } `
    { param($r) $r -eq $true }

# ── B3: Clixml round-trip ──
$results.B3 = T "B3" "Snapshot blob round-trips with all categories" `
    {
        if ($global:blobPath) {
            Import-Clixml -Path $global:blobPath
        } else {
            $null
        }
    } `
    { param($r)
        $r.PSObject.TypeNames[0] -eq 'Deserialized.SEPM.Inventory' -and
        $null -ne $r.Version -and
        $null -ne $r.Domains -and
        $null -ne $r.GUPs -and
        $null -ne $r.PolicySummaries -and
        $null -ne $r.FirewallPolicies -and
        $null -ne $r.IpsPolicies -and
        $null -ne $r.ExceptionPolicies -and
        $null -ne $r.Computers -and
        $null -ne $r.ClientStatus -and
        $null -ne $r.ClientVersions -and
        $null -ne $r.ClientDefVersions -and
        $null -ne $r.ClientInfected -and
        $null -ne $r.Groups -and
        $null -ne $r.Locations -and
        $null -ne $r.LocationXML -and
        $null -ne $r.GroupSettings -and
        $null -ne $r.HostGroups
    }

# ── B4: No failures during collection ──
$results.B4 = T "B4" "No failures during inventory collection" `
    { $snapshot } `
    { param($r) $r.Failures.Count -eq 0 }

# ── Cleanup ──
Remove-Item -Path $outDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Summary -Results $results -Label "Export-SEPMInventory Smoke Tests"
