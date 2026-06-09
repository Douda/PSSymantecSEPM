function Flatten-Adapters {
    <#
    .SYNOPSIS
        Flattens a rule's adapters array into a truncated, human-readable string.
    .DESCRIPTION
        Formats each adapter as "name (type)" and joins with "; ".
        Truncates at 30 items.
    .PARAMETER Adapters
        Array of adapter objects from a firewall rule.
    .PARAMETER MaxItems
        Maximum number of adapters to include. Default: 30.
    .EXAMPLE
        Flatten-Adapters -Adapters $rule.adapters
    #>
    param(
        [AllowNull()]
        [object[]]$Adapters,

        [int]$MaxItems = 30
    )

    if (-not $Adapters -or $Adapters.Count -eq 0) { return '' }

    $formatted = @()
    foreach ($adapter in $Adapters) {
        $name = if ($adapter.name) { $adapter.name } else { '(unnamed)' }
        $type = if ($adapter.type) { " ($($adapter.type))" } else { '' }
        $formatted += "$name$type"
    }

    if ($formatted.Count -gt $MaxItems) {
        $remaining = $formatted.Count - $MaxItems
        $formatted = $formatted[0..($MaxItems - 1)]
        return ($formatted -join '; ') + " ... [$remaining more]"
    }

    return $formatted -join '; '
}
