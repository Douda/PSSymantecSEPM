function Flatten-Apps {
    <#
    .SYNOPSIS
        Flattens a rule's applications array into a truncated string.
    .DESCRIPTION
        Each application's name property is extracted and joined with "; ".
        Truncates at 30 items.
    .PARAMETER Applications
        Array of application objects from a firewall rule.
    .PARAMETER MaxItems
        Maximum number of applications to include. Default: 30.
    .EXAMPLE
        Flatten-Apps -Applications $rule.applications
    #>
    param(
        [AllowNull()]
        [object[]]$Applications,

        [int]$MaxItems = 30
    )

    if (-not $Applications -or $Applications.Count -eq 0) { return '' }

    $names = @($Applications | ForEach-Object { $_.name })
    $names = @($names | Where-Object { $_ })

    if ($names.Count -eq 0) { return '' }

    if ($names.Count -gt $MaxItems) {
        $remaining = $names.Count - $MaxItems
        $names = $names[0..($MaxItems - 1)]
        return ($names -join '; ') + " ... [$remaining more]"
    }

    return $names -join '; '
}
