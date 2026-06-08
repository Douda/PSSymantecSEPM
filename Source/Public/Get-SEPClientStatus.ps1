function Get-SEPClientStatus {
    <#
    .SYNOPSIS
        Gets a list and count of the online and offline clients.
    .DESCRIPTION
        Gets a list and count of the online and offline clients.
    .EXAMPLE
        C:\PSSymantecSEPM> Get-SEPClientStatus

        lastUpdated     clientCountStatsList
        -----------     --------------------
        1693910248728   {@{status=ONLINE; clientsCount=212}, @{status=OFFLINE; clientsCount=48}}

        Gets a list and count of the online and offline clients.
#>
    [CmdletBinding()]
    param()

    begin {
        $session = Initialize-SEPMSession
        $URI = $session.BaseURLv1 + "/stats/client/onlinestatus"

    }

    process {
        $resp = Invoke-SepmApi -Method GET -Uri $URI -Session $session

        $list = $resp.clientCountStatsList
        if ($null -eq $list) { return @() }
        return $list
    }
}
