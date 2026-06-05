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
        # prepare the parameters
        $params = @{
            Session = $session
            Method  = 'GET'
            Uri     = $URI
        }
    
        $resp = Invoke-ABRestMethod -params $params

        # Add a PSTypeName to the object
        $resp.clientCountStatsList | ForEach-Object {
            $_.PSTypeNames.Insert(0, "SEP.clientStatusList")
        }

        return $resp.clientCountStatsList
    }
}
