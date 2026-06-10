function Resolve-SepmCommandTarget {
    <#
    .SYNOPSIS
        Resolves computer names to their unique IDs for command dispatch.
    .DESCRIPTION
        Takes an array of computer names, queries the SEPM API via Get-SEPComputers,
        and returns a hashtable with a computer_ids array.
        The group_ids key is reserved for future group-based targeting.
    .PARAMETER ComputerName
        Array of computer names to resolve.
    .NOTES
        Internal helper. Not exported.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$ComputerName
    )

    $computerIds = @()

    foreach ($name in $ComputerName) {
        $computer = Get-SEPComputers -ComputerName $name | Select-Object -First 1
        if ($computer) {
            $computerIds += $computer.uniqueId
        }
    }

    return @{
        computer_ids = $computerIds
        group_ids    = @()
    }
}
