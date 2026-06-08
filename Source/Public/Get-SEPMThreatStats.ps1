function Get-SEPMThreatStats {
    <#
    .SYNOPSIS
        Gets threat statistics
    .DESCRIPTION
        Gets threat statistics
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPMThreatStats

        Stats
        -----
        @{lastUpdated=1693912098821; infectedClients=1}

        Gets threat statistics
#>

    [CmdletBinding()]
    param()

    begin {
        $session = Initialize-SEPMSession
        $URI = $session.BaseURLv1 + "/stats/threat"

    }

    process {
        $resp = Invoke-SepmApi -Method GET -Uri $URI -Session $session
        return $resp.Stats
    }
}
