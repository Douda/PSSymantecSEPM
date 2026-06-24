function Get-SEPMGUPList {
    <#
    .SYNOPSIS
        Gets a list of group update providers
    .DESCRIPTION
        Gets a list of SEP clients acting as group update providers
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPMGUPList

        Gets a list of GUPs clients
    .EXAMPLE
    PS C:\PSSymantecSEPM> Get-SEPMGUPList | Select-Object Computername, AgentVersion, IpAddress, port

    computerName  agentVersion   ipAddress       port
    ------------  ------------   ---------       ----
    Server01      12.1.7454.7000 10.0.0.150      2967
    Server02      14.3.558.0000  10.1.0.150      2967
    Workstation01 12.1.7454.7000 192.168.0.1     2967
    Workstation02 14.3.558.0000  192.168.1.1     2967

    Gets a list of GUPs clients with specific properties
#>

    [CmdletBinding()]
    param()

    begin {
        $session = Initialize-SEPMSession
        $endpoint = Get-SEPMApiEndpoint -OperationName 'Get-SEPMGUPList'
    }

    process {
        $resp = Invoke-SepmEndpoint -Endpoint $endpoint -Session $session

        Write-Output $resp -NoEnumerate
    }
}
