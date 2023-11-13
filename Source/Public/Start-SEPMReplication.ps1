function Start-SEPMReplication {
    <# TODO update help
    .SYNOPSIS
        Initiates replication with a remote site
    .DESCRIPTION
        Initiates replication with a remote site
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
        $partnerSiteName

        # TODO known bug with SEPM API, these parameters are returning invalid option if not set to false 
        # [switch]
        # $logs,

        # [switch]
        # $ContentAndPackages
    )

    begin {
        # initialize the configuration
        $test_token = Test-SEPMAccessToken
        if (-not $test_token){
            Get-SEPMAccessToken | Out-Null
        }
        $URI = $script:BaseURLv1 + "/replication/replicatenow"
        $headers = @{
            "Authorization" = "Bearer " + $script:accessToken.token
            "Content"       = 'application/json'
        }
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
            headers = $headers
        }
    
        $resp = Invoke-ABRestMethod -params $params
        return $resp
    }
}