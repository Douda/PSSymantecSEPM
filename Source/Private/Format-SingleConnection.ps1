function Format-SingleConnection {
    <#
    .SYNOPSIS
        Formats a single firewall rule connection into a human-readable string.
    .DESCRIPTION
        Produces strings like:
          "Out: TCP:80(remote)"
          "In: ICMP:type 8"
          "Out: ether:34525"
          "Out: fragmented"
          "Out: HTTPS(TCP:443(remote))"
    .PARAMETER Connection
        A single connection object from a firewall rule.
    .EXAMPLE
        Format-SingleConnection -Connection $conn
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSObject]$Connection
    )

    $dirMap = @{ 0 = 'Out'; 1 = 'In'; 2 = 'Both' }
    $direction = $dirMap[[int]$Connection.direction_id]
    if (-not $direction) { $direction = 'Out' }

    $parts = @()

    # --- Named service ---
    if ($Connection.svc_name) {
        $protoAndPorts = Format-ConnectionProtocolAndPorts -Connection $Connection
        if ($protoAndPorts) {
            return "$($direction): $($Connection.svc_name)($protoAndPorts)"
        }
        return "$($direction): $($Connection.svc_name)"
    }

    # --- Ether type ---
    if ($Connection.ether_type_id) {
        return "$($direction): ether:$($Connection.ether_type_id)"
    }

    # --- Fragmented only ---
    if ($Connection.ip_fragmented_only) {
        return "$($direction): fragmented"
    }

    # --- ICMP / ICMPv6 ---
    if ($Connection.icmp_types -and $Connection.icmp_types.Count -gt 0) {
        $protoKeyword = Get-IANAProtocolKeyword -ProtocolNumber $Connection.protocol_ids[0]
        $icmpTypes = ($Connection.icmp_types | ForEach-Object { "type $_" }) -join ','
        return "$($direction): $protoKeyword`:$icmpTypes"
    }

    # --- Protocol + ports ---
    $protoAndPorts = Format-ConnectionProtocolAndPorts -Connection $Connection
    if ($protoAndPorts) {
        return "$($direction): $protoAndPorts"
    }

    # --- Protocol only (no ports, no ICMP) ---
    $protoNames = @()
    if ($Connection.protocol_ids) {
        foreach ($pid in $Connection.protocol_ids) {
            $protoNames += Get-IANAProtocolKeyword -ProtocolNumber $pid
        }
    }
    if ($protoNames.Count -gt 0) {
        return "$($direction): $($protoNames -join ',')"
    }

    return "$($direction): (any)"
}

function Format-ConnectionProtocolAndPorts {
    param([PSObject]$Connection)

    if (-not $Connection.protocol_ids -or $Connection.protocol_ids.Count -eq 0) {
        return $null
    }

    $protoKeyword = Get-IANAProtocolKeyword -ProtocolNumber $Connection.protocol_ids[0]

    if (-not $Connection.ports -or $Connection.ports.Count -eq 0) {
        return $protoKeyword
    }

    $locMap = @{ 'LOCAL' = 'local'; 'REMOTE' = 'remote'; 'DST' = 'dst'; 'SRC' = 'src' }
    $portParts = @()
    foreach ($port in $Connection.ports) {
        $loc = if ($port.location) { $locMap[$port.location] } else { '' }
        if ($port.end -and $port.end -ne $port.start) {
            $portParts += "$($port.start)-$($port.end)($loc)"
        } else {
            $portParts += "$($port.start)($loc)"
        }
    }

    return "$($protoKeyword):$($portParts -join ',')"
}
