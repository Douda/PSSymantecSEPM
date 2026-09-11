function Export-SEPMInventory {
    <#
    .SYNOPSIS
        Exports an inventory snapshot of the SEPM environment.

    .DESCRIPTION
        Gathers data from multiple SEPM cmdlets into a single snapshot object,
        writes per-category .clixml files, and a timestamped snapshot blob.
        Failures from individual sub-cmdlets are captured rather than propagated.

        Two parameter sets: 'ExistingConfig' (the default - the server and credentials are
        already configured via Set-SEPMConfiguration and Set-SEPMAuthentication) and
        'ExplicitAuth' (pass -ServerAddress plus optional -Port, -Credential/-CredentialPath,
        -SkipCertificateCheck to configure, authenticate, and verify the connection in a single
        call for unattended operation).

    .PARAMETER OutputDir
        Directory where exported files are written. Default: 'sepm-data-YYYY-MM-DD',
        a date-stamped folder in the current directory (local time).

    .PARAMETER DelayMs
        Delay in milliseconds between sub-cmdlet calls to reduce API load. Default: 0.

    .PARAMETER ServerAddress
        [ExplicitAuth] SEPM server hostname or IP. Mandatory in this set.

    .PARAMETER Port
        [ExplicitAuth] SEPM server port. Optional; the configured default is used when omitted.

    .PARAMETER Credential
        [ExplicitAuth] PSCredential for the SEPM server. Optional; takes precedence over -CredentialPath.

    .PARAMETER CredentialPath
        [ExplicitAuth] Path to a credentials .xml file to restore. Optional.

    .PARAMETER SkipCertificateCheck
        [ExplicitAuth] Bypass TLS certificate validation (for self-signed certificates).

    .EXAMPLE
        PS C:\> Export-SEPMInventory -OutputDir 'C:\inventory'

        Gathers SEPM data and writes clixml exports to C:\inventory.
    #>

    [CmdletBinding(DefaultParameterSetName = 'ExistingConfig')]
    param(
        # Shared across both parameter sets
        [string]$OutputDir = '',
        [int]$DelayMs = 0,

        # ExplicitAuth parameter set - self-contained auth bootstrap
        [Parameter(Mandatory = $true, ParameterSetName = 'ExplicitAuth')]
        [string]$ServerAddress,

        [Parameter(Mandatory = $false, ParameterSetName = 'ExplicitAuth')]
        [int]$Port,

        [Parameter(Mandatory = $false, ParameterSetName = 'ExplicitAuth')]
        [PSCredential]$Credential,

        [Parameter(Mandatory = $false, ParameterSetName = 'ExplicitAuth')]
        [string]$CredentialPath,

        [Parameter(Mandatory = $false, ParameterSetName = 'ExplicitAuth')]
        [switch]$SkipCertificateCheck
    )

    begin {
        # Default to a date-stamped folder when no explicit OutputDir is given
        if ([string]::IsNullOrEmpty($OutputDir)) {
            $OutputDir = "sepm-data-$(Get-Date -Format 'yyyy-MM-dd')"
        }

        # Self-contained auth bootstrap for the ExplicitAuth parameter set
        if ($PSCmdlet.ParameterSetName -eq 'ExplicitAuth') {
            # 1. Configure the server (partial update of only the provided values)
            $configParams = @{}
            if ($PSBoundParameters.ContainsKey('ServerAddress')) { $configParams['ServerAddress'] = $ServerAddress }
            if ($PSBoundParameters.ContainsKey('Port')) { $configParams['Port'] = $Port }
            if ($configParams.Count -gt 0) { Set-SEPMConfiguration @configParams }

            # 2. Bypass certificate validation if requested
            if ($PSBoundParameters.ContainsKey('SkipCertificateCheck') -and $SkipCertificateCheck) {
                $script:SkipCert = $true
            }

            # 3. Resolve the credential from the most specific source available
            $resolvedCredential = $null
            if ($PSBoundParameters.ContainsKey('Credential') -and $null -ne $Credential) {
                $resolvedCredential = $Credential
            }
            elseif ($PSBoundParameters.ContainsKey('CredentialPath') -and $CredentialPath) {
                Restore-SEPMAuthentication -Path $CredentialPath -Credential
                $resolvedCredential = $script:Credential
            }
            else {
                $resolvedCredential = Get-Credential
            }

            # 4. Store the credential in module scope and persist to disk
            Set-SEPMAuthentication -Credentials $resolvedCredential

            # 5. Invalidate the cached session and any token (memory + disk). The
            #    fail-fast gate below must query SEPM with the NEW credential; a
            #    stale cached token (for a different server/credential) would
            #    otherwise be returned without ever being verified.
            $script:_session = $null
            $script:accessToken = $null
            Remove-Item -Path $script:accessTokenFilePath -Force -ErrorAction SilentlyContinue

            # Verify credentials fail-fast before starting a multi-minute export
            try {
                $null = Get-SEPMAccessToken
                Write-Host '[OK] Authentication verified' -ForegroundColor Green
            }
            catch {
                Write-Host '[FAIL] Provided credentials rejected by SEPM' -ForegroundColor Red
                Write-Host 'Prompting for credentials...' -ForegroundColor Yellow
                $fallbackCredential = Get-Credential
                Set-SEPMAuthentication -Credentials $fallbackCredential
                $script:_session = $null
                $script:accessToken = $null
                Remove-Item -Path $script:accessTokenFilePath -Force -ErrorAction SilentlyContinue
                try {
                    $null = Get-SEPMAccessToken
                    Write-Host '[OK] Authentication verified' -ForegroundColor Green
                }
                catch {
                    throw
                }
            }
        }

        # Create the output directory if it doesn't exist
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

        $progressCounter = 0
        $totalSteps = 25
    }

    process {
        # Pre-fetch groups for GroupList use (avoids redundant API call)
        $groupsForPhase = @()
        try {
            $groupsForPhase = Get-SEPMGroups
        } catch {
            Write-Warning "[0/$totalSteps] Groups: $($_.Exception.Message)"
            $snapshot.Failures += [PSCustomObject]@{
                Category = 'Groups'
                Item     = ''
                ItemId   = ''
                Error    = $_.Exception.Message
            }
        }

        # ── Phase 1: Simple categories (Version, Domains, infra/security) ──
        # Version & Domains each followed by delay
        Invoke-CategoryFetch -Category 'Version' -Snapshot $snapshot -FetchScript { Get-SEPMVersion } -ProgressCounter ([ref]$progressCounter) -TotalSteps $totalSteps
        if ($DelayMs -gt 0) { Start-Sleep -Milliseconds $DelayMs }

        Invoke-CategoryFetch -Category 'Domains' -Snapshot $snapshot -FetchScript { Get-SEPMDomain } -ProgressCounter ([ref]$progressCounter) -TotalSteps $totalSteps
        if ($DelayMs -gt 0) { Start-Sleep -Milliseconds $DelayMs }

        # Infrastructure & Security (no delay between these)
        Invoke-CategoryFetch -Category 'GUPs' -Snapshot $snapshot -FetchScript { Get-SEPMGUPList } -ProgressCounter ([ref]$progressCounter) -TotalSteps $totalSteps
        Invoke-CategoryFetch -Category 'Admins' -Snapshot $snapshot -FetchScript { Get-SEPMAdmins } -ProgressCounter ([ref]$progressCounter) -TotalSteps $totalSteps
        Invoke-CategoryFetch -Category 'DatabaseInfo' -Snapshot $snapshot -FetchScript { Get-SEPMDatabaseInfo } -ProgressCounter ([ref]$progressCounter) -TotalSteps $totalSteps
        Invoke-CategoryFetch -Category 'License' -Snapshot $snapshot -FetchScript { Get-SEPMLicense } -ProgressCounter ([ref]$progressCounter) -TotalSteps $totalSteps
        Invoke-CategoryFetch -Category 'LicenseSummary' -Snapshot $snapshot -FetchScript { Get-SEPMLicense -Summary } -ProgressCounter ([ref]$progressCounter) -TotalSteps $totalSteps
        Invoke-CategoryFetch -Category 'ReplicationStatus' -Snapshot $snapshot -FetchScript { Get-SEPMReplicationStatus } -ProgressCounter ([ref]$progressCounter) -TotalSteps $totalSteps
        Invoke-CategoryFetch -Category 'ThreatStats' -Snapshot $snapshot -FetchScript { Get-SEPMThreatStats } -ProgressCounter ([ref]$progressCounter) -TotalSteps $totalSteps
        Invoke-CategoryFetch -Category 'LatestDefinitions' -Snapshot $snapshot -FetchScript { Get-SEPMLatestDefinition } -ProgressCounter ([ref]$progressCounter) -TotalSteps $totalSteps
        Invoke-CategoryFetch -Category 'Events' -Snapshot $snapshot -FetchScript { Get-SEPMEventInfo } -ProgressCounter ([ref]$progressCounter) -TotalSteps $totalSteps

        # ── Phase 2: PolicySummaries with GroupList ──
        Invoke-CategoryFetch -Category 'PolicySummaries' -Snapshot $snapshot -FetchScript { Get-SEPMPoliciesSummary -GroupList $groupsForPhase } -ProgressCounter ([ref]$progressCounter) -TotalSteps $totalSteps
        if ($DelayMs -gt 0) { Start-Sleep -Milliseconds $DelayMs }

        # ── Phase 3: Per-policy detail ──
        # FirewallPolicies via simple mode (bulk fetch with -All -PolicyList)
        Invoke-CategoryFetch -Category 'FirewallPolicies' -Snapshot $snapshot -FetchScript {
            $fwParams = @{ All = $true; DelayMs = $DelayMs }
            if ($null -ne $snapshot.PolicySummaries) {
                $fwSummaries = @($snapshot.PolicySummaries | Where-Object { $_.policytype -eq 'fw' })
                if ($fwSummaries.Count -gt 0) {
                    $fwParams.PolicyList = $fwSummaries
                }
            }
            Get-SEPMFirewallPolicy @fwParams
        } -ProgressCounter ([ref]$progressCounter) -TotalSteps $totalSteps

        # IpsPolicies via iterative mode per summary
        $ipsSummaries = @()
        if ($null -ne $snapshot.PolicySummaries) {
            $ipsSummaries = @($snapshot.PolicySummaries | Where-Object { $_.policytype -eq 'ips' })
        }
        Invoke-CategoryFetch -Category 'IpsPolicies' -Snapshot $snapshot -Items $ipsSummaries -ItemFetchScript { Get-SEPMIpsPolicy -PolicySummary $_ } -ProgressCounter ([ref]$progressCounter) -TotalSteps $totalSteps -DelayMs $DelayMs

        # ExceptionPolicies via iterative mode per summary
        $excSummaries = @()
        if ($null -ne $snapshot.PolicySummaries) {
            $excSummaries = @($snapshot.PolicySummaries | Where-Object { $_.policytype -eq 'exceptions' })
        }
        Invoke-CategoryFetch -Category 'ExceptionPolicies' -Snapshot $snapshot -Items $excSummaries -ItemFetchScript { Get-SEPMExceptionPolicy -PolicySummary $_ } -ProgressCounter ([ref]$progressCounter) -TotalSteps $totalSteps -DelayMs $DelayMs

        # ── Phase 4: Client data (simple mode) ──
        Invoke-CategoryFetch -Category 'Computers' -Snapshot $snapshot -FetchScript { Get-SEPMComputers } -ProgressCounter ([ref]$progressCounter) -TotalSteps $totalSteps
        Invoke-CategoryFetch -Category 'ClientStatus' -Snapshot $snapshot -FetchScript { Get-SEPMClientStatus } -ProgressCounter ([ref]$progressCounter) -TotalSteps $totalSteps
        Invoke-CategoryFetch -Category 'ClientVersions' -Snapshot $snapshot -FetchScript { Get-SEPMClientVersion } -ProgressCounter ([ref]$progressCounter) -TotalSteps $totalSteps
        Invoke-CategoryFetch -Category 'ClientDefVersions' -Snapshot $snapshot -FetchScript { Get-SEPMClientDefVersions } -ProgressCounter ([ref]$progressCounter) -TotalSteps $totalSteps
        Invoke-CategoryFetch -Category 'ClientInfected' -Snapshot $snapshot -FetchScript {
            $ciParams = @{}
            if ($null -ne $snapshot.Computers) {
                $ciParams.ComputerList = $snapshot.Computers
            }
            Get-SEPMClientInfectedStatus @ciParams
        } -ProgressCounter ([ref]$progressCounter) -TotalSteps $totalSteps

        # Groups (data already pre-fetched, use via simple mode)
        Invoke-CategoryFetch -Category 'Groups' -Snapshot $snapshot -FetchScript { $groupsForPhase } -ProgressCounter ([ref]$progressCounter) -TotalSteps $totalSteps

        # ── Phase 5: Per-group / per-location drill-down ──
        # Locations via iterative mode on Groups
        $locationGroups = @()
        if ($null -ne $snapshot.Groups) {
            $locationGroups = @($snapshot.Groups)
        }
        Invoke-CategoryFetch -Category 'Locations' -Snapshot $snapshot -Items $locationGroups -ItemFetchScript { Get-SEPMLocation -GroupID $_.id -GroupList $locationGroups } -ProgressCounter ([ref]$progressCounter) -TotalSteps $totalSteps -DelayMs $DelayMs

        # LocationXML + GroupSettings: fetched together in same iteration, no separate step for GroupSettings
        $progressCounter++
        Write-Host "[$progressCounter/$totalSteps] LocationXML" -ForegroundColor Cyan
        $categoryFailed = $false
        $categoryStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $allLocationXml = @()
        $allGroupSettings = @()
        $locationItems = @()
        if ($null -ne $snapshot.Locations) {
            $locationItems = @($snapshot.Locations)
        }
        $locCount = $locationItems.Count
        if ($locCount -gt 0) {
            $locIndex = 0
            $locHeartbeatInterval = [Math]::Max(10, [Math]::Floor($locCount / 10))
            foreach ($locItem in $locationItems) {
                $locIndex++
                $locName = $locItem.locationName
                if ($locIndex % $locHeartbeatInterval -eq 0) {
                    Write-Host "  -> LocationXML ($locIndex/$locCount): $locName" -ForegroundColor DarkGray
                }
                # LocationXML fetch
                try {
                    $locXml = Get-SEPMLocationXML -GroupID $locItem.groupId -LocationID $locItem.locationId
                    if ($null -ne $locXml) { $allLocationXml += $locXml }
                } catch {
                    $categoryFailed = $true
                    Write-Warning "[$progressCounter/$totalSteps] LocationXML ($locName): $($_.Exception.Message)"
                    $snapshot.Failures += [PSCustomObject]@{
                        Category = 'LocationXML'
                        Item     = $locName
                        ItemId   = $locItem.locationId
                        Error    = $_.Exception.Message
                    }
                }
                # GroupSettings fetch
                try {
                    $grpSettings = Get-SEPMGroupSettings -groupId $locItem.groupId -locationId $locItem.locationId
                    if ($null -ne $grpSettings) { $allGroupSettings += $grpSettings }
                } catch {
                    $categoryFailed = $true
                    Write-Warning "[$progressCounter/$totalSteps] GroupSettings ($locName): $($_.Exception.Message)"
                    $snapshot.Failures += [PSCustomObject]@{
                        Category = 'GroupSettings'
                        Item     = $locName
                        ItemId   = $locItem.locationId
                        Error    = $_.Exception.Message
                    }
                }
                if ($locIndex -lt $locCount -and $DelayMs -gt 0) { Start-Sleep -Milliseconds $DelayMs }
            }
        }
        $snapshot.LocationXML = $allLocationXml
        $snapshot.GroupSettings = $allGroupSettings
        $categoryStopwatch.Stop()
        Write-CategoryVerboseOutput -Category 'LocationXML' -Data $snapshot.LocationXML -Stopwatch $categoryStopwatch -StepNumber $progressCounter -TotalSteps $totalSteps -Failed $categoryFailed

        # ── Phase 6: HostGroups (iterative mode via summaries) ──
        $progressCounter++
        Write-Host "[$progressCounter/$totalSteps] HostGroups" -ForegroundColor Cyan
        $hgFailed = $false
        $hgStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $allHostGroups = @()
        try {
            $hgSummaries = Get-SEPMHostGroupSummary
            if ($null -ne $hgSummaries) {
                $hgCount = $hgSummaries.Count
                $hgIndex = 0
                $hgHeartbeatInterval = [Math]::Max(10, [Math]::Floor($hgCount / 10))
                foreach ($hg in $hgSummaries) {
                    $hgIndex++
                    $hgName = $hg.name
                    if ($hgIndex % $hgHeartbeatInterval -eq 0) {
                        Write-Verbose "  -> group $hgIndex/$hgCount $hgName"
                        Write-Host "  -> HostGroups ($hgIndex/$hgCount): $hgName" -ForegroundColor DarkGray
                    }
                    try {
                        $hgDetail = Get-SEPMHostGroup -Id $hg.id
                        if ($null -ne $hgDetail) { $allHostGroups += $hgDetail }
                    } catch {
                        $hgFailed = $true
                        Write-Warning "[$progressCounter/$totalSteps] HostGroups ($hgName): $($_.Exception.Message)"
                        $snapshot.Failures += [PSCustomObject]@{
                            Category = 'HostGroups'
                            Item     = $hgName
                            ItemId   = $hg.id
                            Error    = $_.Exception.Message
                        }
                    }
                    if ($hgIndex -lt $hgCount -and $DelayMs -gt 0) { Start-Sleep -Milliseconds $DelayMs }
                }
            }
        } catch {
            $hgFailed = $true
            Write-Warning "[$progressCounter/$totalSteps] HostGroups: $($_.Exception.Message)"
            $snapshot.Failures += [PSCustomObject]@{
                Category = 'HostGroups'
                Item     = ''
                ItemId   = ''
                Error    = $_.Exception.Message
            }
        }
        $snapshot.HostGroups = $allHostGroups
        $hgStopwatch.Stop()
        Write-CategoryVerboseOutput -Category 'HostGroups' -Data $snapshot.HostGroups -Stopwatch $hgStopwatch -StepNumber $progressCounter -TotalSteps $totalSteps -Failed $hgFailed

        # ── Finalize: Write per-category .clixml files via helper ──
        $progressCounter++
        Write-Host "[$progressCounter/$totalSteps] Snapshot" -ForegroundColor Cyan
        $snapStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        Write-InventoryClixml -Snapshot $snapshot -OutputDir $OutputDir
        $snapStopwatch.Stop()
        Write-CategoryVerboseOutput -Category 'Snapshot' -Data 'written' -Stopwatch $snapStopwatch -StepNumber $progressCounter -TotalSteps $totalSteps -Failed $false

        $snapshot
    }
}
