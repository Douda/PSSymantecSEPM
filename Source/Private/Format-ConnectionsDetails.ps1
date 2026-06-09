function Format-ConnectionsDetails {
    <#
    .SYNOPSIS
        Formats all enabled connections of a rule into a human-readable string.
    .DESCRIPTION
        Iterates through enabled connections, formats each with Format-SingleConnection,
        and joins results with "; ".
    .PARAMETER Connections
        Array of connection objects from a firewall rule.
    .EXAMPLE
        Format-ConnectionsDetails -Connections $rule.connections
    #>
    param(
        [AllowNull()]
        [object[]]$Connections
    )

    if (-not $Connections -or $Connections.Count -eq 0) { return '' }

    $enabled = @($Connections | Where-Object { $_.enabled })
    if ($enabled.Count -eq 0) { return '' }

    $formatted = @()
    foreach ($conn in $enabled) {
        $formatted += Format-SingleConnection -Connection $conn
    }

    return ($formatted -join '; ')
}
