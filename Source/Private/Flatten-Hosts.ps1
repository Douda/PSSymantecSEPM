function Flatten-Hosts {
    <#
    .SYNOPSIS
        Flattens a rule's hosts array into a truncated string.
    .DESCRIPTION
        Formats each host entry showing location and IP/MAC info.
        Truncates at 30 items.
    .PARAMETER Hosts
        Array of host objects from a firewall rule.
    .PARAMETER MaxItems
        Maximum number of hosts to include. Default: 30.
    .EXAMPLE
        Flatten-Hosts -Hosts $rule.hosts
    #>
    param(
        [AllowNull()]
        [object[]]$Hosts,

        [int]$MaxItems = 30
    )

    if (-not $Hosts -or $Hosts.Count -eq 0) { return '' }

    $formatted = @()
    foreach ($host in $Hosts) {
        $loc = if ($host.location) { "($($host.location))" } else { '' }
        if ($host.mac) {
            $formatted += "MAC:$($host.mac)$loc"
        } elseif ($host.ip_range) {
            $ip = if ($host.ip_range.start) {
                if ($host.ip_range.end) {
                    "$($host.ip_range.start)-$($host.ip_range.end)"
                } else {
                    $host.ip_range.start
                }
            } else { '(ip)' }
            $formatted += "$ip$loc"
        } else {
            $formatted += "(host)$loc"
        }
    }

    if ($formatted.Count -gt $MaxItems) {
        $remaining = $formatted.Count - $MaxItems
        $formatted = $formatted[0..($MaxItems - 1)]
        return ($formatted -join '; ') + " ... [$remaining more]"
    }

    return $formatted -join '; '
}
