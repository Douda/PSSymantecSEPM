function Export-SEPMInventory {
    <#
    .SYNOPSIS
        Exports an inventory snapshot of the SEPM environment.

    .DESCRIPTION
        Gathers data from multiple SEPM cmdlets into a single snapshot object,
        writes per-category .clixml files, and a timestamped snapshot blob.
        Failures from individual sub-cmdlets are captured rather than propagated.

    .PARAMETER OutputDir
        Directory where exported files are written. Default: current directory ('.').

    .PARAMETER DelayMs
        Delay in milliseconds between sub-cmdlet calls to reduce API load. Default: 0.

    .EXAMPLE
        PS C:\> Export-SEPMInventory -OutputDir 'C:\inventory'

        Gathers SEPM data and writes clixml exports to C:\inventory.
    #>

    [CmdletBinding()]
    param(
        [string]$OutputDir = '.',
        [int]$DelayMs = 0
    )

    begin {
        if (-not (Test-Path -Path $OutputDir)) {
            New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null
        }

        $snapshot = [PSCustomObject]@{
            FetchedAt           = [DateTime]::UtcNow
            Version             = $null
            Domains             = $null
            GUPs                = $null
            Admins              = $null
            DatabaseInfo        = $null
            License             = $null
            LicenseSummary      = $null
            ReplicationStatus   = $null
            ThreatStats         = $null
            LatestDefinitions   = $null
            Events              = $null
            PolicySummaries      = $null
            FirewallPolicies     = $null
            IpsPolicies          = $null
            ExceptionPolicies    = $null
            Computers           = $null
            ClientStatus        = $null
            ClientVersions      = $null
            ClientDefVersions   = $null
            ClientInfected      = $null
            Failures            = @()
        }
        $snapshot.PSObject.TypeNames.Insert(0, 'SEPM.Inventory')
    }

    process {
        # ── Version ──
        try {
            $snapshot.Version = Get-SEPMVersion
        } catch {
            $snapshot.Failures += [PSCustomObject]@{
                Category = 'Version'
                Error    = $_.Exception.Message
            }
            [PSCustomObject]@{ Error = $_.Exception.Message } |
                Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'Version_failed.xml') -Force
        }

        if ($DelayMs -gt 0) { Start-Sleep -Milliseconds $DelayMs }

        # ── Domains ──
        try {
            $snapshot.Domains = Get-SEPMDomain
        } catch {
            $snapshot.Failures += [PSCustomObject]@{
                Category = 'Domains'
                Error    = $_.Exception.Message
            }
            [PSCustomObject]@{ Error = $_.Exception.Message } |
                Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'Domains_failed.xml') -Force
        }

        if ($DelayMs -gt 0) { Start-Sleep -Milliseconds $DelayMs }

        # ── Infrastructure & Security state ──
        # (no DelayMs between these single-call categories)

        # GUPs
        try {
            $snapshot.GUPs = Get-SEPGUPList
        } catch {
            $snapshot.Failures += [PSCustomObject]@{
                Category = 'GUPs'
                Error    = $_.Exception.Message
            }
            [PSCustomObject]@{ Error = $_.Exception.Message } |
                Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'GUPs_failed.xml') -Force
        }

        # Admins
        try {
            $snapshot.Admins = Get-SEPMAdmins
        } catch {
            $snapshot.Failures += [PSCustomObject]@{
                Category = 'Admins'
                Error    = $_.Exception.Message
            }
            [PSCustomObject]@{ Error = $_.Exception.Message } |
                Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'Admins_failed.xml') -Force
        }

        # DatabaseInfo
        try {
            $snapshot.DatabaseInfo = Get-SEPMDatabaseInfo
        } catch {
            $snapshot.Failures += [PSCustomObject]@{
                Category = 'DatabaseInfo'
                Error    = $_.Exception.Message
            }
            [PSCustomObject]@{ Error = $_.Exception.Message } |
                Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'DatabaseInfo_failed.xml') -Force
        }

        # License
        try {
            $snapshot.License = Get-SEPMLicense
        } catch {
            $snapshot.Failures += [PSCustomObject]@{
                Category = 'License'
                Error    = $_.Exception.Message
            }
            [PSCustomObject]@{ Error = $_.Exception.Message } |
                Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'License_failed.xml') -Force
        }

        # LicenseSummary
        try {
            $snapshot.LicenseSummary = Get-SEPMLicense -Summary
        } catch {
            $snapshot.Failures += [PSCustomObject]@{
                Category = 'LicenseSummary'
                Error    = $_.Exception.Message
            }
            [PSCustomObject]@{ Error = $_.Exception.Message } |
                Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'LicenseSummary_failed.xml') -Force
        }

        # ReplicationStatus
        try {
            $snapshot.ReplicationStatus = Get-SEPMReplicationStatus
        } catch {
            $snapshot.Failures += [PSCustomObject]@{
                Category = 'ReplicationStatus'
                Error    = $_.Exception.Message
            }
            [PSCustomObject]@{ Error = $_.Exception.Message } |
                Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'ReplicationStatus_failed.xml') -Force
        }

        # ThreatStats
        try {
            $snapshot.ThreatStats = Get-SEPMThreatStats
        } catch {
            $snapshot.Failures += [PSCustomObject]@{
                Category = 'ThreatStats'
                Error    = $_.Exception.Message
            }
            [PSCustomObject]@{ Error = $_.Exception.Message } |
                Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'ThreatStats_failed.xml') -Force
        }

        # LatestDefinitions
        try {
            $snapshot.LatestDefinitions = Get-SEPMLatestDefinition
        } catch {
            $snapshot.Failures += [PSCustomObject]@{
                Category = 'LatestDefinitions'
                Error    = $_.Exception.Message
            }
            [PSCustomObject]@{ Error = $_.Exception.Message } |
                Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'LatestDefinitions_failed.xml') -Force
        }

        # Events
        try {
            $snapshot.Events = Get-SEPMEventInfo
        } catch {
            $snapshot.Failures += [PSCustomObject]@{
                Category = 'Events'
                Error    = $_.Exception.Message
            }
            [PSCustomObject]@{ Error = $_.Exception.Message } |
                Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'Events_failed.xml') -Force
        }

        # ── PolicySummaries ──
        try {
            $snapshot.PolicySummaries = Get-SEPMPoliciesSummary
        } catch {
            $snapshot.Failures += [PSCustomObject]@{
                Category = 'PolicySummaries'
                Error    = $_.Exception.Message
            }
            [PSCustomObject]@{ Error = $_.Exception.Message } |
                Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'PolicySummaries_failed.xml') -Force
        }

        if ($DelayMs -gt 0) { Start-Sleep -Milliseconds $DelayMs }

        # ── FirewallPolicies ──
        try {
            $snapshot.FirewallPolicies = Get-SEPMFirewallPolicy -All -DelayMs $DelayMs
        } catch {
            $snapshot.Failures += [PSCustomObject]@{
                Category = 'FirewallPolicies'
                Error    = $_.Exception.Message
            }
            [PSCustomObject]@{ Error = $_.Exception.Message } |
                Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'FirewallPolicies_failed.xml') -Force
        }

        # ── IpsPolicies (per-policy fetch from IPS summaries) ──
        $ipsPolicies = @()
        if ($null -ne $snapshot.PolicySummaries) {
            $ipsSummaries = @($snapshot.PolicySummaries | Where-Object { $_.policytype -eq 'ips' })
            $ipsCount = $ipsSummaries.Count
            $ipsIndex = 0
            foreach ($ipsSummary in $ipsSummaries) {
                $ipsIndex++
                try {
                    $ipsPolicy = Get-SEPMIpsPolicy -PolicyName $ipsSummary.name
                    if ($ipsPolicy) {
                        $ipsPolicies += $ipsPolicy
                    }
                } catch {
                    $snapshot.Failures += [PSCustomObject]@{
                        Category = 'IpsPolicies'
                        PolicyName = $ipsSummary.name
                        Error    = $_.Exception.Message
                    }
                    [PSCustomObject]@{
                        Category = 'IpsPolicies'
                        PolicyName = $ipsSummary.name
                        Error    = $_.Exception.Message
                    } | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'IpsPolicies_failed.xml') -Force
                }
                if ($ipsIndex -lt $ipsCount -and $DelayMs -gt 0) { Start-Sleep -Milliseconds $DelayMs }
            }
        }
        $snapshot.IpsPolicies = $ipsPolicies

        # ── ExceptionPolicies (per-policy fetch from exception summaries) ──
        $exceptionPolicies = @()
        if ($null -ne $snapshot.PolicySummaries) {
            $exceptionSummaries = @($snapshot.PolicySummaries | Where-Object { $_.policytype -eq 'exceptions' })
            $exceptionCount = $exceptionSummaries.Count
            $exceptionIndex = 0
            foreach ($exceptionSummary in $exceptionSummaries) {
                $exceptionIndex++
                try {
                    $exceptionPolicy = Get-SEPMExceptionPolicy -PolicyName $exceptionSummary.name
                    if ($exceptionPolicy) {
                        $exceptionPolicies += $exceptionPolicy
                    }
                } catch {
                    $snapshot.Failures += [PSCustomObject]@{
                        Category = 'ExceptionPolicies'
                        PolicyName = $exceptionSummary.name
                        Error    = $_.Exception.Message
                    }
                    [PSCustomObject]@{
                        Category = 'ExceptionPolicies'
                        PolicyName = $exceptionSummary.name
                        Error    = $_.Exception.Message
                    } | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'ExceptionPolicies_failed.xml') -Force
                }
                if ($exceptionIndex -lt $exceptionCount -and $DelayMs -gt 0) { Start-Sleep -Milliseconds $DelayMs }
            }
        }
        $snapshot.ExceptionPolicies = $exceptionPolicies

        # ── Computers ──
        try {
            $snapshot.Computers = Get-SEPComputers
        } catch {
            $snapshot.Failures += [PSCustomObject]@{
                Category = 'Computers'
                Error    = $_.Exception.Message
            }
            [PSCustomObject]@{ Error = $_.Exception.Message } |
                Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'Computers_failed.xml') -Force
        }

        # ── ClientStatus ──
        try {
            $snapshot.ClientStatus = Get-SEPClientStatus
        } catch {
            $snapshot.Failures += [PSCustomObject]@{
                Category = 'ClientStatus'
                Error    = $_.Exception.Message
            }
            [PSCustomObject]@{ Error = $_.Exception.Message } |
                Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'ClientStatus_failed.xml') -Force
        }

        # ── ClientVersions ──
        try {
            $snapshot.ClientVersions = Get-SEPClientVersion
        } catch {
            $snapshot.Failures += [PSCustomObject]@{
                Category = 'ClientVersions'
                Error    = $_.Exception.Message
            }
            [PSCustomObject]@{ Error = $_.Exception.Message } |
                Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'ClientVersions_failed.xml') -Force
        }

        # ── ClientDefVersions ──
        try {
            $snapshot.ClientDefVersions = Get-SEPClientDefVersions
        } catch {
            $snapshot.Failures += [PSCustomObject]@{
                Category = 'ClientDefVersions'
                Error    = $_.Exception.Message
            }
            [PSCustomObject]@{ Error = $_.Exception.Message } |
                Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'ClientDefVersions_failed.xml') -Force
        }

        # ── ClientInfected ──
        try {
            $snapshot.ClientInfected = Get-SEPClientInfectedStatus
        } catch {
            $snapshot.Failures += [PSCustomObject]@{
                Category = 'ClientInfected'
                Error    = $_.Exception.Message
            }
            [PSCustomObject]@{ Error = $_.Exception.Message } |
                Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'ClientInfected_failed.xml') -Force
        }

        # ── Write per-category .clixml files ──
        if ($snapshot.Version) {
            $snapshot.Version | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'all_version.xml') -Force
        }
        if ($snapshot.Domains) {
            $snapshot.Domains | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'all_domains.xml') -Force
        }
        if ($snapshot.GUPs) {
            $snapshot.GUPs | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'all_gups.xml') -Force
        }
        if ($snapshot.Admins) {
            $snapshot.Admins | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'all_admins.xml') -Force
        }
        if ($snapshot.DatabaseInfo) {
            $snapshot.DatabaseInfo | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'all_database_info.xml') -Force
        }
        if ($snapshot.License) {
            $snapshot.License | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'all_license.xml') -Force
        }
        if ($snapshot.LicenseSummary) {
            $snapshot.LicenseSummary | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'all_license_summary.xml') -Force
        }
        if ($snapshot.ReplicationStatus) {
            $snapshot.ReplicationStatus | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'all_replication_status.xml') -Force
        }
        if ($snapshot.ThreatStats) {
            $snapshot.ThreatStats | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'all_threat_stats.xml') -Force
        }
        if ($snapshot.LatestDefinitions) {
            $snapshot.LatestDefinitions | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'all_latest_definitions.xml') -Force
        }
        if ($snapshot.Events) {
            $snapshot.Events | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'all_events.xml') -Force
        }
        if ($null -ne $snapshot.PolicySummaries) {
            $snapshot.PolicySummaries | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'all_policy_summaries.xml') -Force
        }
        if ($null -ne $snapshot.FirewallPolicies) {
            $snapshot.FirewallPolicies | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'all_fw_policies.xml') -Force
        }
        if ($null -ne $snapshot.IpsPolicies) {
            $snapshot.IpsPolicies | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'all_ips_policies.xml') -Force
        }
        if ($null -ne $snapshot.ExceptionPolicies) {
            $snapshot.ExceptionPolicies | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'all_exception_policies.xml') -Force
        }
        if ($null -ne $snapshot.Computers) {
            $snapshot.Computers | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'all_computers.xml') -Force
        }
        if ($null -ne $snapshot.ClientStatus) {
            $snapshot.ClientStatus | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'all_client_status.xml') -Force
        }
        if ($null -ne $snapshot.ClientVersions) {
            $snapshot.ClientVersions | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'all_client_versions.xml') -Force
        }
        if ($null -ne $snapshot.ClientDefVersions) {
            $snapshot.ClientDefVersions | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'all_client_def_versions.xml') -Force
        }
        if ($null -ne $snapshot.ClientInfected) {
            $snapshot.ClientInfected | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'all_client_infected.xml') -Force
        }

        # Write timestamped snapshot blob
        $timestamp = $snapshot.FetchedAt.ToString('yyyy-MM-ddTHH-mm-ss')
        $snapshot | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath "SepmInventory_$timestamp.clixml") -Force

        $snapshot
    }
}
