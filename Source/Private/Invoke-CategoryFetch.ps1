function Invoke-CategoryFetch {
    <#
    .SYNOPSIS
        Fetches data for a single inventory category and stores it in the snapshot.

    .DESCRIPTION
        Two parameter sets:
        - Simple mode (-FetchScript): executes a scriptblock, stores result in $Snapshot.$Category
        - Iterative mode (-Items + -ItemFetchScript): iterates items, fetches per-item data

        Both modes: bump progress counter, emit step header, time execution,
        handle failures with uniform shape, emit verbose summary.

    .PARAMETER Category
        The inventory category name (e.g. 'Domains', 'Computers').

    .PARAMETER Snapshot
        The snapshot PSCustomObject to store results into.

    .PARAMETER FetchScript
        A scriptblock that returns the data for this category (Simple mode only).

    .PARAMETER Items
        Array of items to iterate over (Iterative mode only).

    .PARAMETER ItemFetchScript
        A scriptblock that takes a single item and returns fetched data (Iterative mode only).

    .PARAMETER ItemNameScript
        A scriptblock to extract the item display name (default: { $_.name }).

    .PARAMETER ItemIdScript
        A scriptblock to extract the item ID (default: { $_.id }).

    .PARAMETER ProgressCounter
        A [ref] to the progress counter integer. Bumped exactly once per invocation.

    .PARAMETER TotalSteps
        Total number of categories being fetched.

    .PARAMETER DelayMs
        Delay in milliseconds between item fetches (Iterative mode, default: 0).

    .EXAMPLE
        Invoke-CategoryFetch -Category 'Domains' -Snapshot $snap -FetchScript { Get-SEPMDomain } -ProgressCounter ([ref]$pc) -TotalSteps 25

    .EXAMPLE
        Invoke-CategoryFetch -Category 'IpsPolicies' -Snapshot $snap -Items $summaries -ItemFetchScript { Get-SEPMIpsPolicy -PolicySummary $_ } -ProgressCounter ([ref]$pc) -TotalSteps 25 -DelayMs 200
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Category,

        [Parameter(Mandatory = $true)]
        [object]$Snapshot,

        [Parameter(Mandatory = $true, ParameterSetName = 'Simple')]
        [scriptblock]$FetchScript,

        [Parameter(Mandatory = $true, ParameterSetName = 'Iterative')]
        [AllowEmptyCollection()]
        [object[]]$Items,

        [Parameter(Mandatory = $true, ParameterSetName = 'Iterative')]
        [scriptblock]$ItemFetchScript,

        [Parameter(ParameterSetName = 'Iterative')]
        [scriptblock]$ItemNameScript = { $_.name },

        [Parameter(ParameterSetName = 'Iterative')]
        [scriptblock]$ItemIdScript = { $_.id },

        [Parameter(Mandatory = $true)]
        [ref]$ProgressCounter,

        [Parameter(Mandatory = $true)]
        [int]$TotalSteps,

        [Parameter(ParameterSetName = 'Iterative')]
        [int]$DelayMs = 0
    )

    $ProgressCounter.Value++

    # Emit step header
    Write-Host "[$($ProgressCounter.Value)/$TotalSteps] $Category" -ForegroundColor Cyan

    $categoryFailed = $false
    $categoryStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    if ($PSCmdlet.ParameterSetName -eq 'Simple') {
        try {
            $Snapshot.$Category = & $FetchScript
        } catch {
            $categoryFailed = $true
            Write-Warning "[$($ProgressCounter.Value)/$TotalSteps] $($Category): $($_.Exception.Message)"
            $Snapshot.Failures += [PSCustomObject]@{
                Category = $Category
                Item     = ''
                ItemId   = ''
                Error    = $_.Exception.Message
            }
        }
    } else {
        # Iterative mode
        $results = @()
        $itemCount = @($Items).Count

        if ($itemCount -gt 0) {
            $heartbeatInterval = [Math]::Max(10, [Math]::Floor($itemCount / 10))
            $itemIndex = 0

            foreach ($item in $Items) {
                $itemIndex++

                $itemName = $item | ForEach-Object $ItemNameScript
                $itemId   = $item | ForEach-Object $ItemIdScript

                if ($itemIndex % $heartbeatInterval -eq 0) {
                    Write-Host "  -> $Category ($itemIndex/$itemCount): $itemName" -ForegroundColor DarkGray
                }

                try {
                    $fetched = $item | ForEach-Object $ItemFetchScript
                    if ($null -ne $fetched) {
                        $results += $fetched
                    }
                } catch {
                    $categoryFailed = $true
                    Write-Warning "[$($ProgressCounter.Value)/$TotalSteps] $Category ($itemName): $($_.Exception.Message)"
                    $Snapshot.Failures += [PSCustomObject]@{
                        Category = $Category
                        Item     = $itemName
                        ItemId   = $itemId
                        Error    = $_.Exception.Message
                    }
                }

                if ($itemIndex -lt $itemCount -and $DelayMs -gt 0) {
                    Start-Sleep -Milliseconds $DelayMs
                }
            }
        }

        $Snapshot.$Category = $results
    }

    $categoryStopwatch.Stop()
    Write-CategoryVerboseOutput -Category $Category -Data $Snapshot.$Category -Stopwatch $categoryStopwatch -StepNumber $ProgressCounter.Value -TotalSteps $TotalSteps -Failed $categoryFailed
}
