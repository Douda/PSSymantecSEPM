function Get-SEPMClientInfectedStatus {
    <# 
    .SYNOPSIS
        Gets SEP Clients with Infected or Clean status
    .DESCRIPTION
        Gets SEP Clients with Infected or Clean status
        NOTES : Clean status is just Infected = 0

    .INPUTS
        None
    .OUTPUTS
        List of SEP Clients with Infected status
    .PARAMETER ComputerList
        An array of computer objects to filter by infected status.
        When provided, the cmdlet filters this list instead of calling Get-SEPMComputers.
    .PARAMETER Clean
        If specified, returns SEP Clients with Clean status
    .EXAMPLE
        Get-SEPMClientInfectedStatus

        Gets computer details for all computers in the domain
    .EXAMPLE
        Get-SEPMClientInfectedStatus -Clean

        Gets computer details for all computers in the domain that are not infected
    .EXAMPLE
        Get-SEPMComputers | Get-SEPMClientInfectedStatus -ComputerList $_ -Clean

        Filters already fetched computers for clean status
#>

    [CmdletBinding()]
    param (
        [Parameter()]
        [object[]]
        $ComputerList,

        [Parameter()]
        [switch]
        $Clean
    )

    process {
        if ($PSBoundParameters.ContainsKey('ComputerList')) {
            $computers = $ComputerList
        } else {
            $computers = Get-SEPMComputers
        }

        if ($Clean) {
            $non_infected = @($computers | Where-Object { $_.infected -ne 1 })
            Write-Output $non_infected -NoEnumerate
        } else {
            $infected = @($computers | Where-Object { $_.infected -eq 1 })
            Write-Output $infected -NoEnumerate
        }
    }
}
