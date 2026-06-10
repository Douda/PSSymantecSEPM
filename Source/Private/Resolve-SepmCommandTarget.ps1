function Resolve-SepmCommandTarget {
    <#
    .SYNOPSIS
        Resolves computer names or group names to their unique IDs for command dispatch.
    .DESCRIPTION
        Takes an array of computer names or a group full path name, queries the SEPM API,
        and returns a hashtable with computer_ids and/or group_ids arrays.
    .PARAMETER ComputerName
        Array of computer names to resolve.
    .PARAMETER GroupName
        Full path name of the group to resolve (e.g. "My Company\Workstations").
    .NOTES
        Internal helper. Not exported.
    #>

    [CmdletBinding(DefaultParameterSetName = 'ComputerName')]
    param (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = 'ComputerName'
        )]
        [string[]]$ComputerName,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = 'GroupName'
        )]
        [string]$GroupName
    )

    if ($PSCmdlet.ParameterSetName -eq 'GroupName') {
        $allGroups = Get-SEPMGroups
        $group = $null
        foreach ($g in $allGroups) {
            if ($g.fullPathName -eq $GroupName) {
                $group = $g
                break
            }
        }
        if (-not $group) {
            Write-Error "Group not found: $GroupName"
            return @{
                computer_ids = @()
                group_ids    = @()
            }
        }
        return @{
            computer_ids = @()
            group_ids    = @($group.id)
        }
    }

    $computerIds = @()
    $unmatchedNames = @()

    foreach ($name in $ComputerName) {
        $computer = Get-SEPComputers -ComputerName $name | Select-Object -First 1
        if ($computer) {
            $computerIds += $computer.uniqueId
        } else {
            $unmatchedNames += $name
        }
    }

    if ($unmatchedNames.Count -gt 0) {
        Write-Error "The following names were not found: $($unmatchedNames -join ', ')"
    }

    return @{
        computer_ids = $computerIds
        group_ids    = @()
    }
}
