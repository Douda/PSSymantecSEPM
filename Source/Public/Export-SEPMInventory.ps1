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
            Groups              = $null
            Locations           = $null
            LocationXML         = $null
            GroupSettings       = $null
            HostGroups          = $null
            Failures            = @()
        }
        $snapshot.PSObject.TypeNames.Insert(0, 'SEPM.Inventory')
    }

    process {
        $totalSteps = 25
        $progressCounter = 0

        function Write-ExportProgress {
            param(
                [ref]$Counter,
                [int]$Total,
                [string]$StepName
            )
            $Counter.Value++
            Write-Progress -Activity 'Export-SEPMInventory' -Status "[$($Counter.Value)/$Total] $StepName" -PercentComplete ($Counter.Value / $Total * 100)
        }

        function Get-CategoryMetric {
            param([string]$Category, [object]$Data, [bool]$Failed = $false)

            if ($Failed) { return 'error' }
            if ($null -eq $Data) { return '' }

            $count = @($Data).Count

            switch ($Category) {
                'Version' {
                    if ($Data -is [hashtable] -or $Data -is [PSCustomObject]) {
                        $v = if ($Data.version) { $Data.version } elseif ($Data.API_VERSION) { $Data.API_VERSION } else { $Data }
                        return "$v"
                    }
                    return "$count entries"
                }
                'Domains' { return "$count domain$(if($count -eq 1){''}else{'s'})" }
                'GUPs' { return "$count GUP$(if($count -eq 1){''}else{'s'})" }
                'Admins' { return "$count admin$(if($count -eq 1){''}else{'s'})" }
                'DatabaseInfo' { return "$($Data.type)" }
                'License' { return "$($Data.productName)" }
                'LicenseSummary' { return "$($Data.license_type)" }
                'ReplicationStatus' { return "$count site$(if($count -eq 1){''}else{'s'})" }
                'ThreatStats' { return "$count stat$(if($count -eq 1){''}else{'s'})" }
                'LatestDefinitions' { return "$($Data.contentName)" }
                'Events' { return "$count event$(if($count -eq 1){''}else{'s'})" }
                'PolicySummaries' { return "$count polic$(if($count -eq 1){'y'}else{'ies'})" }
                'FirewallPolicies' { return "$count polic$(if($count -eq 1){'y'}else{'ies'})" }
                'IpsPolicies' { return "$count polic$(if($count -eq 1){'y'}else{'ies'})" }
                'ExceptionPolicies' { return "$count polic$(if($count -eq 1){'y'}else{'ies'})" }
                'Computers' { return "$count computer$(if($count -eq 1){''}else{'s'})" }
                'ClientStatus' { return "$count statu$(if($count -eq 1){'s'}else{'ses'})" }
                'ClientVersions' { return "$count entr$(if($count -eq 1){'y'}else{'ies'})" }
                'ClientDefVersions' { return "$count entr$(if($count -eq 1){'y'}else{'ies'})" }
                'ClientInfected' { return "$count client$(if($count -eq 1){''}else{'s'})" }
                'Groups' { return "$count group$(if($count -eq 1){''}else{'s'})" }
                'Locations' { return "$count location$(if($count -eq 1){''}else{'s'})" }
                'LocationXML' { return "$count entr$(if($count -eq 1){'y'}else{'ies'})" }
                'GroupSettings' { return "$count entr$(if($count -eq 1){'y'}else{'ies'})" }
                'HostGroups' { return "$count group$(if($count -eq 1){''}else{'s'})" }
                'Snapshot' { return 'snapshot written' }
                default { return "$count entries" }
            }
        }

        function Write-CategoryVerbose {
            param(
                [string]$Category,
                [object]$Data,
                [System.Diagnostics.Stopwatch]$Stopwatch,
                [int]$StepNumber,
                [int]$TotalSteps,
                [bool]$Failed = $false
            )

            $ts = Get-Date -Format "HH:mm:ss"

            $elapsed = [DateTime]::UtcNow - $snapshot.FetchedAt
            if ($elapsed.TotalMinutes -ge 1) {
                $elapsedStr = "[+$([Math]::Floor($elapsed.TotalMinutes))m $($elapsed.Seconds)s]"
            } else {
                $elapsedStr = "[+$($elapsed.ToString('ss'))s]"
            }

            $stepStr = "[$($StepNumber.ToString('00'))/$TotalSteps]"

            if ($Failed) { $status = 'FAILED' }
            elseif ($null -eq $Data) { $status = 'OK (empty)' }
            elseif ($Data -is [System.Collections.ICollection] -and $Data.Count -eq 0) { $status = 'OK (empty)' }
            elseif ($Data -is [array] -and $Data.Count -eq 0) { $status = 'OK (empty)' }
            else { $status = 'OK' }

            $metric = Get-CategoryMetric -Category $Category -Data $Data -Failed $Failed

            if ($Stopwatch.Elapsed.TotalSeconds -ge 1) {
                $durationStr = "($($Stopwatch.Elapsed.TotalSeconds.ToString('F1'))s)"
            } else {
                $durationStr = "($($Stopwatch.ElapsedMilliseconds)ms)"
            }

            Write-Verbose "[$ts] $elapsedStr $stepStr $($Category.PadRight(20)) $status`t$metric`t$durationStr"
        }

        # ── Version ──
        Write-ExportProgress -Counter ([ref]$progressCounter) -Total $totalSteps -StepName 'Version'
        $__catFailed = $false
        $__catSw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $snapshot.Version = Get-SEPMVersion
        } catch {
            $__catFailed = $true
            $snapshot.Failures += [PSCustomObject]@{
                Category = 'Version'
                Error    = $_.Exception.Message
            }
            [PSCustomObject]@{ Error = $_.Exception.Message } |
                Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'Version_failed.xml') -Force
        }
        $__catSw.Stop()
        Write-CategoryVerbose -Category 'Version' -Data $snapshot.Version -Stopwatch $__catSw -StepNumber $progressCounter -TotalSteps $totalSteps -Failed $__catFailed

        if ($DelayMs -gt 0) { Start-Sleep -Milliseconds $DelayMs }

        # ── Domains ──
        Write-ExportProgress -Counter ([ref]$progressCounter) -Total $totalSteps -StepName 'Domains'
        $__catFailed = $false
        $__catSw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $snapshot.Domains = Get-SEPMDomain
        } catch {
            $__catFailed = $true
            $snapshot.Failures += [PSCustomObject]@{
                Category = 'Domains'
                Error    = $_.Exception.Message
            }
            [PSCustomObject]@{ Error = $_.Exception.Message } |
                Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'Domains_failed.xml') -Force
        }
        $__catSw.Stop()
        Write-CategoryVerbose -Category 'Domains' -Data $snapshot.Domains -Stopwatch $__catSw -StepNumber $progressCounter -TotalSteps $totalSteps -Failed $__catFailed

        if ($DelayMs -gt 0) { Start-Sleep -Milliseconds $DelayMs }

        # ── Infrastructure & Security state ──
        # (no DelayMs between these single-call categories)

        # GUPs
        Write-ExportProgress -Counter ([ref]$progressCounter) -Total $totalSteps -StepName 'GUPs'
        $__catFailed = $false
        $__catSw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $snapshot.GUPs = Get-SEPGUPList
        } catch {
            $__catFailed = $true
            $snapshot.Failures += [PSCustomObject]@{
                Category = 'GUPs'
                Error    = $_.Exception.Message
            }
            [PSCustomObject]@{ Error = $_.Exception.Message } |
                Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'GUPs_failed.xml') -Force
        }
        $__catSw.Stop()
        Write-CategoryVerbose -Category 'GUPs' -Data $snapshot.GUPs -Stopwatch $__catSw -StepNumber $progressCounter -TotalSteps $totalSteps -Failed $__catFailed

        # Admins
        Write-ExportProgress -Counter ([ref]$progressCounter) -Total $totalSteps -StepName 'Admins'
        $__catFailed = $false
        $__catSw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $snapshot.Admins = Get-SEPMAdmins
        } catch {
            $__catFailed = $true
            $snapshot.Failures += [PSCustomObject]@{
                Category = 'Admins'
                Error    = $_.Exception.Message
            }
            [PSCustomObject]@{ Error = $_.Exception.Message } |
                Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'Admins_failed.xml') -Force
        }
        $__catSw.Stop()
        Write-CategoryVerbose -Category 'Admins' -Data $snapshot.Admins -Stopwatch $__catSw -StepNumber $progressCounter -TotalSteps $totalSteps -Failed $__catFailed

        # DatabaseInfo
        Write-ExportProgress -Counter ([ref]$progressCounter) -Total $totalSteps -StepName 'DatabaseInfo'
        $__catFailed = $false
        $__catSw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $snapshot.DatabaseInfo = Get-SEPMDatabaseInfo
        } catch {
            $__catFailed = $true
            $snapshot.Failures += [PSCustomObject]@{
                Category = 'DatabaseInfo'
                Error    = $_.Exception.Message
            }
            [PSCustomObject]@{ Error = $_.Exception.Message } |
                Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'DatabaseInfo_failed.xml') -Force
        }
        $__catSw.Stop()
        Write-CategoryVerbose -Category 'DatabaseInfo' -Data $snapshot.DatabaseInfo -Stopwatch $__catSw -StepNumber $progressCounter -TotalSteps $totalSteps -Failed $__catFailed

        # License
        Write-ExportProgress -Counter ([ref]$progressCounter) -Total $totalSteps -StepName 'License'
        $__catFailed = $false
        $__catSw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $snapshot.License = Get-SEPMLicense
        } catch {
            $__catFailed = $true
            $snapshot.Failures += [PSCustomObject]@{
                Category = 'License'
                Error    = $_.Exception.Message
            }
            [PSCustomObject]@{ Error = $_.Exception.Message } |
                Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'License_failed.xml') -Force
        }
        $__catSw.Stop()
        Write-CategoryVerbose -Category 'License' -Data $snapshot.License -Stopwatch $__catSw -StepNumber $progressCounter -TotalSteps $totalSteps -Failed $__catFailed

        # LicenseSummary
        Write-ExportProgress -Counter ([ref]$progressCounter) -Total $totalSteps -StepName 'LicenseSummary'
        $__catFailed = $false
        $__catSw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $snapshot.LicenseSummary = Get-SEPMLicense -Summary
        } catch {
            $__catFailed = $true
            $snapshot.Failures += [PSCustomObject]@{
                Category = 'LicenseSummary'
                Error    = $_.Exception.Message
            }
            [PSCustomObject]@{ Error = $_.Exception.Message } |
                Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'LicenseSummary_failed.xml') -Force
        }
        $__catSw.Stop()
        Write-CategoryVerbose -Category 'LicenseSummary' -Data $snapshot.LicenseSummary -Stopwatch $__catSw -StepNumber $progressCounter -TotalSteps $totalSteps -Failed $__catFailed

        # ReplicationStatus
        Write-ExportProgress -Counter ([ref]$progressCounter) -Total $totalSteps -StepName 'ReplicationStatus'
        $__catFailed = $false
        $__catSw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $snapshot.ReplicationStatus = Get-SEPMReplicationStatus
        } catch {
            $__catFailed = $true
            $snapshot.Failures += [PSCustomObject]@{
                Category = 'ReplicationStatus'
                Error    = $_.Exception.Message
            }
            [PSCustomObject]@{ Error = $_.Exception.Message } |
                Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'ReplicationStatus_failed.xml') -Force
        }
        $__catSw.Stop()
        Write-CategoryVerbose -Category 'ReplicationStatus' -Data $snapshot.ReplicationStatus -Stopwatch $__catSw -StepNumber $progressCounter -TotalSteps $totalSteps -Failed $__catFailed

        # ThreatStats
        Write-ExportProgress -Counter ([ref]$progressCounter) -Total $totalSteps -StepName 'ThreatStats'
        $__catFailed = $false
        $__catSw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $snapshot.ThreatStats = Get-SEPMThreatStats
        } catch {
            $__catFailed = $true
            $snapshot.Failures += [PSCustomObject]@{
                Category = 'ThreatStats'
                Error    = $_.Exception.Message
            }
            [PSCustomObject]@{ Error = $_.Exception.Message } |
                Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'ThreatStats_failed.xml') -Force
        }
        $__catSw.Stop()
        Write-CategoryVerbose -Category 'ThreatStats' -Data $snapshot.ThreatStats -Stopwatch $__catSw -StepNumber $progressCounter -TotalSteps $totalSteps -Failed $__catFailed

        # LatestDefinitions
        Write-ExportProgress -Counter ([ref]$progressCounter) -Total $totalSteps -StepName 'LatestDefinitions'
        $__catFailed = $false
        $__catSw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $snapshot.LatestDefinitions = Get-SEPMLatestDefinition
        } catch {
            $__catFailed = $true
            $snapshot.Failures += [PSCustomObject]@{
                Category = 'LatestDefinitions'
                Error    = $_.Exception.Message
            }
            [PSCustomObject]@{ Error = $_.Exception.Message } |
                Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'LatestDefinitions_failed.xml') -Force
        }
        $__catSw.Stop()
        Write-CategoryVerbose -Category 'LatestDefinitions' -Data $snapshot.LatestDefinitions -Stopwatch $__catSw -StepNumber $progressCounter -TotalSteps $totalSteps -Failed $__catFailed

        # Events
        Write-ExportProgress -Counter ([ref]$progressCounter) -Total $totalSteps -StepName 'Events'
        $__catFailed = $false
        $__catSw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $snapshot.Events = Get-SEPMEventInfo
        } catch {
            $__catFailed = $true
            $snapshot.Failures += [PSCustomObject]@{
                Category = 'Events'
                Error    = $_.Exception.Message
            }
            [PSCustomObject]@{ Error = $_.Exception.Message } |
                Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'Events_failed.xml') -Force
        }
        $__catSw.Stop()
        Write-CategoryVerbose -Category 'Events' -Data $snapshot.Events -Stopwatch $__catSw -StepNumber $progressCounter -TotalSteps $totalSteps -Failed $__catFailed

        # ── PolicySummaries ──
        Write-ExportProgress -Counter ([ref]$progressCounter) -Total $totalSteps -StepName 'PolicySummaries'
        $__catFailed = $false
        $__catSw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $snapshot.PolicySummaries = Get-SEPMPoliciesSummary
        } catch {
            $__catFailed = $true
            $snapshot.Failures += [PSCustomObject]@{
                Category = 'PolicySummaries'
                Error    = $_.Exception.Message
            }
            [PSCustomObject]@{ Error = $_.Exception.Message } |
                Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'PolicySummaries_failed.xml') -Force
        }
        $__catSw.Stop()
        Write-CategoryVerbose -Category 'PolicySummaries' -Data $snapshot.PolicySummaries -Stopwatch $__catSw -StepNumber $progressCounter -TotalSteps $totalSteps -Failed $__catFailed

        if ($DelayMs -gt 0) { Start-Sleep -Milliseconds $DelayMs }

        # ── FirewallPolicies ──
        Write-ExportProgress -Counter ([ref]$progressCounter) -Total $totalSteps -StepName 'FirewallPolicies'
        $__catFailed = $false
        $__catSw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $snapshot.FirewallPolicies = Get-SEPMFirewallPolicy -All -DelayMs $DelayMs -SuppressProgress
        } catch {
            $__catFailed = $true
            $snapshot.Failures += [PSCustomObject]@{
                Category = 'FirewallPolicies'
                Error    = $_.Exception.Message
            }
            [PSCustomObject]@{ Error = $_.Exception.Message } |
                Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'FirewallPolicies_failed.xml') -Force
        }
        $__catSw.Stop()
        Write-CategoryVerbose -Category 'FirewallPolicies' -Data $snapshot.FirewallPolicies -Stopwatch $__catSw -StepNumber $progressCounter -TotalSteps $totalSteps -Failed $__catFailed

        # ── IpsPolicies (per-policy fetch from IPS summaries) ──
        Write-ExportProgress -Counter ([ref]$progressCounter) -Total $totalSteps -StepName 'IpsPolicies'
        $__catFailed = $false
        $__catSw = [System.Diagnostics.Stopwatch]::StartNew()
        $ipsPolicies = @()
        if ($null -ne $snapshot.PolicySummaries) {
            $ipsSummaries = @($snapshot.PolicySummaries | Where-Object { $_.policytype -eq 'ips' })
            $ipsCount = $ipsSummaries.Count
            $ipsIndex = 0
            $ipsHeartbeatInterval = [Math]::Max(10, [Math]::Floor($ipsCount / 10))
            foreach ($ipsSummary in $ipsSummaries) {
                $ipsIndex++
                if ($ipsIndex % $ipsHeartbeatInterval -eq 0) {
                    Write-Verbose "  → policy $ipsIndex/$ipsCount $($ipsSummary.name)"
                }
                try {
                    $ipsPolicy = Get-SEPMIpsPolicy -PolicyName $ipsSummary.name
                    if ($ipsPolicy) {
                        $ipsPolicies += $ipsPolicy
                    }
                } catch {
                    $__catFailed = $true
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
        $__catSw.Stop()
        Write-CategoryVerbose -Category 'IpsPolicies' -Data $snapshot.IpsPolicies -Stopwatch $__catSw -StepNumber $progressCounter -TotalSteps $totalSteps -Failed $__catFailed

        # ── ExceptionPolicies (per-policy fetch from exception summaries) ──
        Write-ExportProgress -Counter ([ref]$progressCounter) -Total $totalSteps -StepName 'ExceptionPolicies'
        $__catFailed = $false
        $__catSw = [System.Diagnostics.Stopwatch]::StartNew()
        $exceptionPolicies = @()
        if ($null -ne $snapshot.PolicySummaries) {
            $exceptionSummaries = @($snapshot.PolicySummaries | Where-Object { $_.policytype -eq 'exceptions' })
            $exceptionCount = $exceptionSummaries.Count
            $exceptionIndex = 0
            $excHeartbeatInterval = [Math]::Max(10, [Math]::Floor($exceptionCount / 10))
            foreach ($exceptionSummary in $exceptionSummaries) {
                $exceptionIndex++
                if ($exceptionIndex % $excHeartbeatInterval -eq 0) {
                    Write-Verbose "  → policy $exceptionIndex/$exceptionCount $($exceptionSummary.name)"
                }
                try {
                    $exceptionPolicy = Get-SEPMExceptionPolicy -PolicyName $exceptionSummary.name
                    if ($exceptionPolicy) {
                        $exceptionPolicies += $exceptionPolicy
                    }
                } catch {
                    $__catFailed = $true
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
        $__catSw.Stop()
        Write-CategoryVerbose -Category 'ExceptionPolicies' -Data $snapshot.ExceptionPolicies -Stopwatch $__catSw -StepNumber $progressCounter -TotalSteps $totalSteps -Failed $__catFailed

        # ── Computers ──
        Write-ExportProgress -Counter ([ref]$progressCounter) -Total $totalSteps -StepName 'Computers'
        $__catFailed = $false
        $__catSw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $snapshot.Computers = Get-SEPComputers
        } catch {
            $__catFailed = $true
            $snapshot.Failures += [PSCustomObject]@{
                Category = 'Computers'
                Error    = $_.Exception.Message
            }
            [PSCustomObject]@{ Error = $_.Exception.Message } |
                Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'Computers_failed.xml') -Force
        }
        $__catSw.Stop()
        Write-CategoryVerbose -Category 'Computers' -Data $snapshot.Computers -Stopwatch $__catSw -StepNumber $progressCounter -TotalSteps $totalSteps -Failed $__catFailed

        # ── ClientStatus ──
        Write-ExportProgress -Counter ([ref]$progressCounter) -Total $totalSteps -StepName 'ClientStatus'
        $__catFailed = $false
        $__catSw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $snapshot.ClientStatus = Get-SEPClientStatus
        } catch {
            $__catFailed = $true
            $snapshot.Failures += [PSCustomObject]@{
                Category = 'ClientStatus'
                Error    = $_.Exception.Message
            }
            [PSCustomObject]@{ Error = $_.Exception.Message } |
                Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'ClientStatus_failed.xml') -Force
        }
        $__catSw.Stop()
        Write-CategoryVerbose -Category 'ClientStatus' -Data $snapshot.ClientStatus -Stopwatch $__catSw -StepNumber $progressCounter -TotalSteps $totalSteps -Failed $__catFailed

        # ── ClientVersions ──
        Write-ExportProgress -Counter ([ref]$progressCounter) -Total $totalSteps -StepName 'ClientVersions'
        $__catFailed = $false
        $__catSw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $snapshot.ClientVersions = Get-SEPClientVersion
        } catch {
            $__catFailed = $true
            $snapshot.Failures += [PSCustomObject]@{
                Category = 'ClientVersions'
                Error    = $_.Exception.Message
            }
            [PSCustomObject]@{ Error = $_.Exception.Message } |
                Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'ClientVersions_failed.xml') -Force
        }
        $__catSw.Stop()
        Write-CategoryVerbose -Category 'ClientVersions' -Data $snapshot.ClientVersions -Stopwatch $__catSw -StepNumber $progressCounter -TotalSteps $totalSteps -Failed $__catFailed

        # ── ClientDefVersions ──
        Write-ExportProgress -Counter ([ref]$progressCounter) -Total $totalSteps -StepName 'ClientDefVersions'
        $__catFailed = $false
        $__catSw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $snapshot.ClientDefVersions = Get-SEPClientDefVersions
        } catch {
            $__catFailed = $true
            $snapshot.Failures += [PSCustomObject]@{
                Category = 'ClientDefVersions'
                Error    = $_.Exception.Message
            }
            [PSCustomObject]@{ Error = $_.Exception.Message } |
                Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'ClientDefVersions_failed.xml') -Force
        }
        $__catSw.Stop()
        Write-CategoryVerbose -Category 'ClientDefVersions' -Data $snapshot.ClientDefVersions -Stopwatch $__catSw -StepNumber $progressCounter -TotalSteps $totalSteps -Failed $__catFailed

        # ── ClientInfected ──
        Write-ExportProgress -Counter ([ref]$progressCounter) -Total $totalSteps -StepName 'ClientInfected'
        $__catFailed = $false
        $__catSw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $snapshot.ClientInfected = Get-SEPClientInfectedStatus
        } catch {
            $__catFailed = $true
            $snapshot.Failures += [PSCustomObject]@{
                Category = 'ClientInfected'
                Error    = $_.Exception.Message
            }
            [PSCustomObject]@{ Error = $_.Exception.Message } |
                Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'ClientInfected_failed.xml') -Force
        }
        $__catSw.Stop()
        Write-CategoryVerbose -Category 'ClientInfected' -Data $snapshot.ClientInfected -Stopwatch $__catSw -StepNumber $progressCounter -TotalSteps $totalSteps -Failed $__catFailed

        # ── Groups ──
        Write-ExportProgress -Counter ([ref]$progressCounter) -Total $totalSteps -StepName 'Groups'
        $__catFailed = $false
        $__catSw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $snapshot.Groups = Get-SEPMGroups
        } catch {
            $__catFailed = $true
            $snapshot.Failures += [PSCustomObject]@{
                Category = 'Groups'
                Error    = $_.Exception.Message
            }
            [PSCustomObject]@{ Error = $_.Exception.Message } |
                Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'Groups_failed.xml') -Force
        }
        $__catSw.Stop()
        Write-CategoryVerbose -Category 'Groups' -Data $snapshot.Groups -Stopwatch $__catSw -StepNumber $progressCounter -TotalSteps $totalSteps -Failed $__catFailed

        # ── Locations (per-group enumeration) ──
        Write-ExportProgress -Counter ([ref]$progressCounter) -Total $totalSteps -StepName 'Locations'
        $__catFailed = $false
        $__catSw = [System.Diagnostics.Stopwatch]::StartNew()
        $allLocations = @()
        if ($null -ne $snapshot.Groups) {
            $groupsArray = $snapshot.Groups
            $groupCount = $groupsArray.Count
            $groupIndex = 0
            $locHeartbeatInterval = [Math]::Max(10, [Math]::Floor($groupCount / 10))
            foreach ($group in $groupsArray) {
                $groupIndex++
                if ($groupIndex % $locHeartbeatInterval -eq 0) {
                    Write-Verbose "  → group $groupIndex/$groupCount $($group.name)"
                }
                try {
                    $groupLocs = Get-SEPMLocation -GroupID $group.id
                    $allLocations += $groupLocs
                } catch {
                    $__catFailed = $true
                    $snapshot.Failures += [PSCustomObject]@{
                        Category  = 'Locations'
                        GroupID   = $group.id
                        GroupName = $group.name
                        Error     = $_.Exception.Message
                    }
                    [PSCustomObject]@{
                        Category  = 'Locations'
                        GroupID   = $group.id
                        GroupName = $group.name
                        Error     = $_.Exception.Message
                    } | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'Locations_failed.xml') -Force
                }
                if ($groupIndex -lt $groupCount -and $DelayMs -gt 0) { Start-Sleep -Milliseconds $DelayMs }
            }
        }
        $snapshot.Locations = $allLocations
        $__catSw.Stop()
        Write-CategoryVerbose -Category 'Locations' -Data $snapshot.Locations -Stopwatch $__catSw -StepNumber $progressCounter -TotalSteps $totalSteps -Failed $__catFailed

        # ── LocationXML & GroupSettings (per-group-location drill-down) ──
        Write-ExportProgress -Counter ([ref]$progressCounter) -Total $totalSteps -StepName 'LocationXML'
        $__catFailed = $false
        $__catSw = [System.Diagnostics.Stopwatch]::StartNew()
        $allLocationXml = @()
        $allGroupSettings = @()
        if ($null -ne $snapshot.Locations -and $snapshot.Locations.Count -gt 0) {
            $locations = $snapshot.Locations
            $locationCount = $locations.Count
            $locationIndex = 0
            $locXmlHeartbeatInterval = [Math]::Max(10, [Math]::Floor($locationCount / 10))
            foreach ($location in $locations) {
                $locationIndex++
                if ($locationIndex % $locXmlHeartbeatInterval -eq 0) {
                    Write-Verbose "  → location $locationIndex/$locationCount $($location.locationName)"
                }
                # LocationXML
                try {
                    $locationXml = Get-SEPMLocationXML -GroupID $location.groupId -LocationID $location.locationId
                    if ($null -ne $locationXml) {
                        $allLocationXml += $locationXml
                    }
                } catch {
                    $__catFailed = $true
                    $snapshot.Failures += [PSCustomObject]@{
                        Category   = 'LocationXML'
                        GroupID    = $location.groupId
                        GroupName  = $location.groupName
                        LocationID = $location.locationId
                        Error      = $_.Exception.Message
                    }
                    [PSCustomObject]@{
                        Category   = 'LocationXML'
                        GroupID    = $location.groupId
                        GroupName  = $location.groupName
                        LocationID = $location.locationId
                        Error      = $_.Exception.Message
                    } | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'LocationXML_failed.xml') -Force
                }

                # GroupSettings
                try {
                    $groupSettings = Get-SEPMGroupSettings -groupId $location.groupId -locationId $location.locationId
                    if ($null -ne $groupSettings) {
                        $allGroupSettings += $groupSettings
                    }
                } catch {
                    $__catFailed = $true
                    $snapshot.Failures += [PSCustomObject]@{
                        Category   = 'GroupSettings'
                        GroupID    = $location.groupId
                        GroupName  = $location.groupName
                        LocationID = $location.locationId
                        Error      = $_.Exception.Message
                    }
                    [PSCustomObject]@{
                        Category   = 'GroupSettings'
                        GroupID    = $location.groupId
                        GroupName  = $location.groupName
                        LocationID = $location.locationId
                        Error      = $_.Exception.Message
                    } | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'GroupSettings_failed.xml') -Force
                }

                if ($locationIndex -lt $locationCount -and $DelayMs -gt 0) { Start-Sleep -Milliseconds $DelayMs }
            }
        }
        $snapshot.LocationXML = $allLocationXml
        $snapshot.GroupSettings = $allGroupSettings
        $__catSw.Stop()
        Write-CategoryVerbose -Category 'LocationXML' -Data $snapshot.LocationXML -Stopwatch $__catSw -StepNumber $progressCounter -TotalSteps $totalSteps -Failed $__catFailed

        # ── Host Groups (summary → per-ID detail) ──
        Write-ExportProgress -Counter ([ref]$progressCounter) -Total $totalSteps -StepName 'HostGroups'
        $__catFailed = $false
        $__catSw = [System.Diagnostics.Stopwatch]::StartNew()
        $allHostGroups = @()
        try {
            $hostGroupSummaries = Get-SEPMHostGroupSummary
            if ($null -ne $hostGroupSummaries) {
                $hgCount = $hostGroupSummaries.Count
                $hgIndex = 0
                $hgHeartbeatInterval = [Math]::Max(10, [Math]::Floor($hgCount / 10))
                foreach ($hg in $hostGroupSummaries) {
                    $hgIndex++
                    if ($hgIndex % $hgHeartbeatInterval -eq 0) {
                        Write-Verbose "  → group $hgIndex/$hgCount $($hg.name)"
                    }
                    try {
                        $hgDetail = Get-SEPMHostGroup -Id $hg.id
                        if ($null -ne $hgDetail) {
                            $allHostGroups += $hgDetail
                        }
                    } catch {
                        $__catFailed = $true
                        $snapshot.Failures += [PSCustomObject]@{
                            Category = 'HostGroups'
                            HostGroupID   = $hg.id
                            HostGroupName = $hg.name
                            Error     = $_.Exception.Message
                        }
                        [PSCustomObject]@{
                            Category = 'HostGroups'
                            HostGroupID   = $hg.id
                            HostGroupName = $hg.name
                            Error     = $_.Exception.Message
                        } | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'HostGroups_failed.xml') -Force
                    }
                    if ($hgIndex -lt $hgCount -and $DelayMs -gt 0) { Start-Sleep -Milliseconds $DelayMs }
                }
            }
        } catch {
            $__catFailed = $true
            $snapshot.Failures += [PSCustomObject]@{
                Category = 'HostGroups'
                Error    = $_.Exception.Message
            }
            [PSCustomObject]@{
                Category = 'HostGroups'
                Error    = $_.Exception.Message
            } | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'HostGroups_failed.xml') -Force
        }
        $snapshot.HostGroups = $allHostGroups
        $__catSw.Stop()
        Write-CategoryVerbose -Category 'HostGroups' -Data $snapshot.HostGroups -Stopwatch $__catSw -StepNumber $progressCounter -TotalSteps $totalSteps -Failed $__catFailed

        # ── Write per-category .clixml files ──
        Write-ExportProgress -Counter ([ref]$progressCounter) -Total $totalSteps -StepName 'Snapshot'
        if ($null -ne $snapshot.Version) {
            $snapshot.Version | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'all_version.xml') -Force
        }
        if ($null -ne $snapshot.Domains) {
            $snapshot.Domains | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'all_domains.xml') -Force
        }
        if ($null -ne $snapshot.GUPs) {
            $snapshot.GUPs | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'all_gups.xml') -Force
        }
        if ($null -ne $snapshot.Admins) {
            $snapshot.Admins | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'all_admins.xml') -Force
        }
        if ($null -ne $snapshot.DatabaseInfo) {
            $snapshot.DatabaseInfo | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'all_database_info.xml') -Force
        }
        if ($null -ne $snapshot.License) {
            $snapshot.License | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'all_license.xml') -Force
        }
        if ($null -ne $snapshot.LicenseSummary) {
            $snapshot.LicenseSummary | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'all_license_summary.xml') -Force
        }
        if ($null -ne $snapshot.ReplicationStatus) {
            $snapshot.ReplicationStatus | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'all_replication_status.xml') -Force
        }
        if ($null -ne $snapshot.ThreatStats) {
            $snapshot.ThreatStats | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'all_threat_stats.xml') -Force
        }
        if ($null -ne $snapshot.LatestDefinitions) {
            $snapshot.LatestDefinitions | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'all_latest_definitions.xml') -Force
        }
        if ($null -ne $snapshot.Events) {
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
        if ($null -ne $snapshot.Groups) {
            $snapshot.Groups | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'all_groups.xml') -Force
        }
        if ($null -ne $snapshot.Locations) {
            $snapshot.Locations | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'all_locations.xml') -Force
        }
        if ($null -ne $snapshot.LocationXML -and $snapshot.LocationXML.Count -gt 0) {
            $snapshot.LocationXML | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'all_location_xml.xml') -Force
        }
        if ($null -ne $snapshot.GroupSettings -and $snapshot.GroupSettings.Count -gt 0) {
            $snapshot.GroupSettings | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'all_group_settings.xml') -Force
        }
        if ($null -ne $snapshot.HostGroups) {
            $snapshot.HostGroups | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'all_host_groups.xml') -Force
        }

        # Write timestamped snapshot blob
        $timestamp = $snapshot.FetchedAt.ToString('yyyy-MM-ddTHH-mm-ss')
        $__catSw = [System.Diagnostics.Stopwatch]::StartNew()
        $snapshot | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath "SepmInventory_$timestamp.clixml") -Force
        $__catSw.Stop()
        Write-CategoryVerbose -Category 'Snapshot' -Data 'written' -Stopwatch $__catSw -StepNumber $progressCounter -TotalSteps $totalSteps -Failed $false

        $snapshot
    }
}
