function Flatten-Connections {
    <#
    .SYNOPSIS
        Flattens a rule's connections array into a deduplicated, truncated JSON string.
    .DESCRIPTION
        Filters to enabled connections only, deduplicates by JSON serialization,
        returns a compact JSON array string. Truncates at 30 items.
    .PARAMETER Connections
        Array of connection objects from a firewall rule.
    .PARAMETER MaxItems
        Maximum number of connections to include. Default: 30.
    .EXAMPLE
        Flatten-Connections -Connections $rule.connections
    #>
    param(
        [AllowNull()]
        [object[]]$Connections,

        [int]$MaxItems = 30
    )

    if (-not $Connections -or $Connections.Count -eq 0) { return '' }

    # Filter to enabled only
    $enabled = @($Connections | Where-Object { $_.enabled })

    # Deduplicate by JSON serialization
    $seen = @{}
    $unique = @()
    foreach ($conn in $enabled) {
        $key = $conn | ConvertTo-Json -Compress
        if (-not $seen.ContainsKey($key)) {
            $seen[$key] = $true
            $unique += $conn
        }
    }

    $total = $unique.Count
    if ($total -gt $MaxItems) {
        $unique = $unique[0..($MaxItems - 1)]
    }

    $json = $unique | ConvertTo-Json -Compress

    if ($total -gt $MaxItems) {
        $remaining = $total - $MaxItems
        $json += " ... [$remaining more]"
    }

    return $json
}
