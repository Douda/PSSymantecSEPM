function Get-SEPMClientStatus {
    <#
    .SYNOPSIS
        Gets a list and count of the online and offline clients.
    .DESCRIPTION
        Gets a list and count of the online and offline clients.
    .EXAMPLE
        C:\PSSymantecSEPM> Get-SEPMClientStatus

        lastUpdated     clientCountStatsList
        -----------     --------------------
        1693910248728   {@{status=ONLINE; clientsCount=212}, @{status=OFFLINE; clientsCount=48}}

        Gets a list and count of the online and offline clients.
#>
    [CmdletBinding()]
    param()

    begin {
        $session = Initialize-SEPMSession
        $endpoint = Get-SEPMApiEndpoint -OperationName 'Get-SEPMClientStatus'
    }

    process {
        $resp = Invoke-SepmEndpoint -Endpoint $endpoint -Session $session

        $list = $resp.clientCountStatsList
        if ($null -eq $list) { return @() }
        Write-Output $list -NoEnumerate
    }
}
