<#
.SYNOPSIS
    Shared smoke tests for Export-SEPMInventory.

.DESCRIPTION
    Dot-sourced by run.ps7.ps1 and run.ps51.ps1 after Common.ps1.
    Covers: SEPM.Inventory type, FetchedAt, all 11 categories,
            per-category clixml, timestamped blob, round-trip, DelayMs.
#>

$results = @{}
$outDir = Join-Path $RepoRoot 'Output/smoke-inventory'

# ── A1: Returns SEPM.Inventory PSTypeName ──
$results.A1 = T "A1" "Export-SEPMInventory returns SEPM.Inventory PSTypeName" `
    { Export-SEPMInventory -OutputDir $outDir } `
    { param($r)
        $r -ne $null -and
        $r.PSObject.TypeNames[0] -eq 'SEPM.Inventory'
    }

# ── A2: FetchedAt is DateTime and recent ──
$results.A2 = T "A2" "FetchedAt is a DateTime within last 2 minutes" `
    { Export-SEPMInventory -OutputDir $outDir } `
    { param($r)
        $r.FetchedAt -is [DateTime] -and
        $r.FetchedAt -gt [DateTime]::UtcNow.AddMinutes(-2)
    }

# ── A3: Version populated with real SEPM data ──
$results.A3 = T "A3" "Version property has API_SEQUENCE, API_VERSION, version" `
    { Export-SEPMInventory -OutputDir $outDir } `
    { param($r)
        $r.Version -ne $null -and
        -not [string]::IsNullOrEmpty($r.Version.API_SEQUENCE) -and
        -not [string]::IsNullOrEmpty($r.Version.version)
    }

# ── A4: Domains populated (Default domain) ──
$results.A4 = T "A4" "Domains has id and name properties" `
    { Export-SEPMInventory -OutputDir $outDir } `
    { param($r)
        $r.Domains -ne $null -and
        -not [string]::IsNullOrEmpty($r.Domains.id) -and
        -not [string]::IsNullOrEmpty($r.Domains.name)
    }

# ── A5: GUPs non-null (may be empty if no GUPs configured) ──
$results.A5 = T "A5" "GUPs property is not null" `
    { Export-SEPMInventory -OutputDir $outDir } `
    { param($r) $null -ne $r.GUPs }

# ── A6: Admins populated ──
$results.A6 = T "A6" "Admins has entries with loginName property" `
    { Export-SEPMInventory -OutputDir $outDir } `
    { param($r)
        $null -ne $r.Admins -and
        ($r.Admins | Select-Object -First 1).loginName -ne $null
    }

# ── A7: DatabaseInfo populated ──
$results.A7 = T "A7" "DatabaseInfo has type property" `
    { Export-SEPMInventory -OutputDir $outDir } `
    { param($r)
        $r.DatabaseInfo -ne $null -and
        -not [string]::IsNullOrEmpty($r.DatabaseInfo.type)
    }

# ── A8: License populated ──
$results.A8 = T "A8" "License has serialNumber property" `
    { Export-SEPMInventory -OutputDir $outDir } `
    { param($r)
        $r.License -ne $null -and
        -not [string]::IsNullOrEmpty($r.License.serialNumber)
    }

# ── A9: LicenseSummary populated ──
$results.A9 = T "A9" "LicenseSummary has license_type property" `
    { Export-SEPMInventory -OutputDir $outDir } `
    { param($r)
        $r.LicenseSummary -ne $null -and
        -not [string]::IsNullOrEmpty($r.LicenseSummary.license_type)
    }

# ── A10: ReplicationStatus populated ──
$results.A10 = T "A10" "ReplicationStatus has entries with siteName property" `
    { Export-SEPMInventory -OutputDir $outDir } `
    { param($r)
        $null -ne $r.ReplicationStatus -and
        ($r.ReplicationStatus | Select-Object -First 1).siteName -ne $null
    }

# ── A11: ThreatStats populated ──
$results.A11 = T "A11" "ThreatStats has entries with infectedClients property" `
    { Export-SEPMInventory -OutputDir $outDir } `
    { param($r)
        $null -ne $r.ThreatStats -and
        ($r.ThreatStats | Select-Object -First 1).infectedClients -ne $null
    }

# ── A12: LatestDefinitions populated ──
$results.A12 = T "A12" "LatestDefinitions has contentName property" `
    { Export-SEPMInventory -OutputDir $outDir } `
    { param($r)
        $r.LatestDefinitions -ne $null -and
        -not [string]::IsNullOrEmpty($r.LatestDefinitions.contentName)
    }

# ── A13: Events populated ──
$results.A13 = T "A13" "Events has entries with subject property" `
    { Export-SEPMInventory -OutputDir $outDir } `
    { param($r)
        $null -ne $r.Events -and
        ($r.Events | Select-Object -First 1).subject -ne $null
    }

# ── A14: Per-category clixml files written ──
$results.A14 = T "A14" "Writes all category .clixml files" `
    {
        Export-SEPMInventory -OutputDir $outDir | Out-Null
        $allExist = $true
        $files = @(
            'all_version.xml', 'all_domains.xml', 'all_admins.xml',
            'all_database_info.xml', 'all_license.xml', 'all_license_summary.xml',
            'all_replication_status.xml', 'all_threat_stats.xml',
            'all_latest_definitions.xml', 'all_events.xml'
        )
        foreach ($f in $files) {
            if (-not (Test-Path (Join-Path $outDir $f))) { $allExist = $false }
        }
        $allExist
    } `
    { param($r) $r -eq $true }

# ── A15: Timestamped blob written ──
$results.A15 = T "A15" "Writes timestamped SepmInventory_*.clixml blob" `
    {
        $blobs = Get-ChildItem -Path $outDir -Filter 'SepmInventory_*.clixml' -ErrorAction SilentlyContinue
        $blobs.Count -gt 0
    } `
    { param($r) $r -eq $true }

# ── A16: Clixml round-trip ──
$results.A16 = T "A16" "Snapshot blob round-trips with all categories" `
    {
        $blob = Get-ChildItem -Path $outDir -Filter 'SepmInventory_*.clixml' |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        Import-Clixml -Path $blob.FullName
    } `
    { param($r)
        $r.PSObject.TypeNames[0] -eq 'Deserialized.SEPM.Inventory' -and
        $null -ne $r.Version -and
        $null -ne $r.Domains -and
        $null -ne $r.GUPs
    }

# ── A17: DelayMs does not error ──
$results.A17 = T "A17" "-DelayMs 50 does not error and returns snapshot" `
    { Export-SEPMInventory -OutputDir $outDir -DelayMs 50 } `
    { param($r)
        $r -ne $null -and
        $r.PSObject.TypeNames[0] -eq 'SEPM.Inventory'
    }

# ── Cleanup ──
Remove-Item -Path $outDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Summary -Results $results -Label "Export-SEPMInventory Smoke Tests"
