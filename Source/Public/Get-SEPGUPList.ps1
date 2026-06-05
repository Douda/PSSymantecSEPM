function Get-SEPGUPList {
    <#
    .SYNOPSIS
        Gets a list of group update providers
    .DESCRIPTION
        Gets a list of SEP clients acting as group update providers
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPGUPList

        Gets a list of GUPs clients
    .EXAMPLE
    PS C:\PSSymantecSEPM> Get-SEPGUPList | Select-Object Computername, AgentVersion, IpAddress, port

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
        $URI = $session.BaseURLv1 + "/gup/status"

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
        $resp | ForEach-Object {
            $_.PSTypeNames.Insert(0, "SEP.GUPList")
        }

        return $resp
    }
}
