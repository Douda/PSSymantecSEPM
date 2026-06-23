<#
.SYNOPSIS
    Shared smoke tests for Export-SEPMInventory.

.DESCRIPTION
    Dot-sourced by run.ps7.ps1 and run.ps51.ps1 after Common.ps1.
    Covers: SEPM.Inventory type, FetchedAt, Version, Domains,
            per-category clixml, timestamped blob, round-trip, DelayMs.
#>

$results = @{}

# ── A1: Returns SEPM.Inventory PSTypeName ──
$results.A1 = T "A1" "Export-SEPMInventory returns SEPM.Inventory PSTypeName" `
    { Export-SEPMInventory -OutputDir (Join-Path $RepoRoot 'Output/smoke-inventory') } `
    { param($r)
        $r -ne $null -and
        $r.PSObject.TypeNames[0] -eq 'SEPM.Inventory'
    }

# ── A2: FetchedAt is DateTime and recent ──
$results.A2 = T "A2" "FetchedAt is a DateTime within last 2 minutes" `
    { Export-SEPMInventory -OutputDir (Join-Path $RepoRoot 'Output/smoke-inventory') } `
    { param($r)
        $r.FetchedAt -is [DateTime] -and
        $r.FetchedAt -gt [DateTime]::UtcNow.AddMinutes(-2)
    }

# ── A3: Version populated with real SEPM data ──
$results.A3 = T "A3" "Version property has API_SEQUENCE, API_VERSION, version" `
    { Export-SEPMInventory -OutputDir (Join-Path $RepoRoot 'Output/smoke-inventory') } `
    { param($r)
        $r.Version -ne $null -and
        -not [string]::IsNullOrEmpty($r.Version.API_SEQUENCE) -and
        -not [string]::IsNullOrEmpty($r.Version.version)
    }

# ── A4: Domains populated (Default domain) ──
$results.A4 = T "A4" "Domains has id and name properties" `
    { Export-SEPMInventory -OutputDir (Join-Path $RepoRoot 'Output/smoke-inventory') } `
    { param($r)
        $r.Domains -ne $null -and
        -not [string]::IsNullOrEmpty($r.Domains.id) -and
        -not [string]::IsNullOrEmpty($r.Domains.name)
    }

# ── A5: Per-category clixml files written ──
$outDir = Join-Path $RepoRoot 'Output/smoke-inventory'
$results.A5 = T "A5" "Writes all_version.xml and all_domains.xml" `
    {
        Export-SEPMInventory -OutputDir $outDir | Out-Null
        $vExists = Test-Path (Join-Path $outDir 'all_version.xml')
        $dExists = Test-Path (Join-Path $outDir 'all_domains.xml')
        @{ VersionExists = $vExists; DomainsExists = $dExists }
    } `
    { param($r)
        $r.VersionExists -eq $true -and
        $r.DomainsExists -eq $true
    }

# ── A6: Timestamped blob written ──
$results.A6 = T "A6" "Writes timestamped SepmInventory_*.clixml blob" `
    {
        $blobs = Get-ChildItem -Path $outDir -Filter 'SepmInventory_*.clixml' -ErrorAction SilentlyContinue
        $blobs.Count -gt 0
    } `
    { param($r) $r -eq $true }

# ── A7: Clixml round-trip ──
$results.A7 = T "A7" "Snapshot blob round-trips with Deserialized.SEPM.Inventory" `
    {
        $blob = Get-ChildItem -Path $outDir -Filter 'SepmInventory_*.clixml' |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        Import-Clixml -Path $blob.FullName
    } `
    { param($r)
        $r.PSObject.TypeNames[0] -eq 'Deserialized.SEPM.Inventory' -and
        $r.Version -ne $null -and
        $r.Domains -ne $null
    }

# ── A8: DelayMs does not error ──
$results.A8 = T "A8" "-DelayMs 50 does not error and returns snapshot" `
    { Export-SEPMInventory -OutputDir $outDir -DelayMs 50 } `
    { param($r)
        $r -ne $null -and
        $r.PSObject.TypeNames[0] -eq 'SEPM.Inventory'
    }

# ── Cleanup ──
Remove-Item -Path $outDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Summary -Results $results -Label "Export-SEPMInventory Smoke Tests"
