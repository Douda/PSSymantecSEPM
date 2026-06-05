function Get-SEPMThreatStats {
    <#
    .SYNOPSIS
        Gets threat statistics
    .DESCRIPTION
        Gets threat statistics
    .PARAMETER SkipCertificateCheck
        Skip certificate check
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPMThreatStats

        Stats
        -----
        @{lastUpdated=1693912098821; infectedClients=1}

        Gets threat statistics
#>

    [CmdletBinding()]
    param (
        # Skip certificate check
        [Parameter()]
        [switch]
        $SkipCertificateCheck
    )

    begin {
        $session = Initialize-SEPMSession -SkipCertificateCheck:$SkipCertificateCheck
        $URI = $session.BaseURLv1 + "/stats/threat"
    }

    process {
        # prepare the parameters
        $params = @{
            Method  = 'GET'
            Uri     = $URI
            headers = $session.Headers
        }
    
        $resp = Invoke-ABRestMethod -params $params
        return $resp.Stats
    }
}