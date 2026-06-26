function Write-CategoryVerboseOutput {
    <#
    .SYNOPSIS
        Formats and writes a per-category verbose summary line.

    .DESCRIPTION
        Produces a single line of verbose output for Export-SEPMInventory
        with format: [timestamp] [+elapsed] [step/total] CATEGORY STATUS  metric  (duration).
        Calls Get-CategoryMetric internally to produce the metric column.

    .PARAMETER Category
        The inventory category name (e.g. 'Domains', 'Computers').

    .PARAMETER Data
        The data object for the category. Can be an array, hashtable,
        PSCustomObject, or null.

    .PARAMETER Stopwatch
        A running System.Diagnostics.Stopwatch measuring the category's
        fetch duration.

    .PARAMETER StepNumber
        Current step number (1-based).

    .PARAMETER TotalSteps
        Total number of steps in the export.

    .PARAMETER Failed
        If $true, the category fetch failed and status is 'FAILED'.

    .EXAMPLE
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        Start-Sleep -Milliseconds 10
        $sw.Stop()
        Write-CategoryVerboseOutput -Category 'Domains' -Data @('d1','d2') -Stopwatch $sw -StepNumber 1 -TotalSteps 25 -Failed $false
        # Writes verbose line like: [14:30:00] [+2s] [01/25] Domains             OK      2 domains   (12.3ms)
    #>

    [CmdletBinding()]
    param(
        [string]$Category,
        [object]$Data,
        [System.Diagnostics.Stopwatch]$Stopwatch,
        [int]$StepNumber,
        [int]$TotalSteps,
        [bool]$Failed = $false
    )

    $ts = Get-Date -Format "HH:mm:ss"

    $elapsed = $Stopwatch.Elapsed
    if ($elapsed.TotalMinutes -ge 1) {
        $elapsedStr = "[+$([Math]::Floor($elapsed.TotalMinutes))m $($elapsed.Seconds)s]"
    } else {
        $elapsedStr = "[+$($elapsed.ToString('ss'))s]"
    }

    $stepStr = "[$($StepNumber.ToString('00'))/$TotalSteps]"

    if ($Failed) { $status = 'FAILED' }
    elseif ($null -eq $Data) { $status = 'OK (empty)' }
    elseif ($Data -is [System.Collections.ICollection] -and $Data.Count -eq 0) { $status = 'OK (empty)' }
    else { $status = 'OK' }

    $metric = Get-CategoryMetric -Category $Category -Data $Data -Failed $Failed

    if ($Stopwatch.Elapsed.TotalSeconds -ge 1) {
        $durationStr = "($($Stopwatch.Elapsed.TotalSeconds.ToString('F1'))s)"
    } else {
        $durationStr = "($($Stopwatch.ElapsedMilliseconds)ms)"
    }

    Write-Verbose "[$ts] $elapsedStr $stepStr $($Category.PadRight(20)) $status`t$metric`t$durationStr"
}
