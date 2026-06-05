function Start-SEPMReplication {
    <# TODO update help
    .SYNOPSIS
        Initiates replication with a remote site
    .DESCRIPTION
        Initiates replication with a remote site
    .PARAMETER partnerSiteName
        The name of the remote site to replicate with
    .PARAMETER SkipCertificateCheck
        Skip certificate check
    .EXAMPLE
        PS C:\PSSymantecSEPM> Start-SEPMReplication -partnerSiteName "Remote site Americas"

        code
        ----
        0

        Initiates replication with the remote site Americas. Response code 0 indicates success.
#>

    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $partnerSiteName,

        # Skip certificate check
        [Parameter()]
        [switch]
        $SkipCertificateCheck

        # TODO known bug with SEPM API, these parameters are returning invalid option if not set to false 
        # [switch]
        # $logs,

        # [switch]
        # $ContentAndPackages
    )

    begin {
        $session = Initialize-SEPMSession -SkipCertificateCheck:$SkipCertificateCheck
        $URI = $session.BaseURLv1 + "/replication/replicatenow"
    }

    process {
        # URI query strings
        $QueryStrings = @{
            partnerSiteName = $partnerSiteName
            logs            = $logs
            content         = $ContentAndPackages
        }

        # Construct the URI
        $URI = Build-SEPMQueryURI -BaseURI $URI -QueryStrings $QueryStrings

        # prepare the parameters
        $params = @{
            Method  = 'POST'
            Uri     = $URI
            headers = $session.Headers
        }
    
        $resp = Invoke-ABRestMethod -params $params
        return $resp
    }
}