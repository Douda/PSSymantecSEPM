function Get-SEPComputers {
    <#
    .SYNOPSIS
        Gets the information about the computers in a specified domain
    .DESCRIPTION
        Gets the information about the computers in a specified domain. either from computer names or group names
    .PARAMETER ComputerName
        Specifies the name of the computer for which you want to get the information. Supports wildcards
    .PARAMETER GroupName
        Specifies the group full path name for which you want to get the information. Supports wildcards
    .PARAMETER IncludeSubGroups
        Specifies whether to include subgroups when querying by group name
    .EXAMPLE
        Get-SEPComputers

        Gets computer details for all computers in the domain
    .EXAMPLE
        "MyComputer1","MyComputer2" | Get-SEPComputers

        Gets computer details for the specified computer MyComputer via pipeline
    .EXAMPLE
        Get-SEPComputers -ComputerName "MyComputer*"

        Gets computer details for all computer names starting by MyComputer
    .EXAMPLE
        Get-SEPComputers -GroupName "My Company\EMEA\Workstations"

        Gets computer details for all computers in the specified group MyGroup
    .EXAMPLE
        Get-SEPComputers -GroupName "My Company\EMEA\Workstations" -IncludeSubGroups

        Gets computer details for all computers in the specified group MyGroup and its subgroups
#>
    [CmdletBinding(
        DefaultParameterSetName = 'ComputerName'
    )]
    Param (
        # ComputerName
        [Parameter(
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'ComputerName'
        )]
        [Alias("Hostname", "DeviceName", "Device", "Computer")]
        [String]
        $ComputerName,

        # group name
        [Parameter(
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'GroupName'
        )]
        [Alias("Group")]
        [String]
        $GroupName,

        # switch parameter to include subgroups
        [Parameter(
            ParameterSetName = 'GroupName'
        )]
        [switch]
        $IncludeSubGroups
    )

    begin {
        $session = Initialize-SEPMSession
        $endpoint = Get-SEPMApiEndpoint -OperationName 'Get-SEPComputers'
    }

    process {

        if ($ComputerName) {
            $allResults = Invoke-SepmEndpoint -Endpoint $endpoint -Session $session -BoundParameters $PSBoundParameters

            # Filtering (PS 5.1: @() wrapper prevents Where-Object scalar unrolling)
            $allResults = @($allResults | Where-Object { $_.computerName -like $ComputerName })
        }

        elseif ($GroupName) {
            $allResults = Invoke-SepmEndpoint -Endpoint $endpoint -Session $session

            # Filtering (PS 5.1: @() wrapper prevents Where-Object scalar unrolling)
            if ($IncludeSubGroups) {
                $allResults = @($allResults | Where-Object { $_.group.name -like "$GroupName*" })
            } else {
                $allResults = @($allResults | Where-Object { $_.group.name -eq $GroupName })
            }
        }

        else {
            $allResults = Invoke-SepmEndpoint -Endpoint $endpoint -Session $session
        }

        Write-Output $allResults -NoEnumerate
    }
}
