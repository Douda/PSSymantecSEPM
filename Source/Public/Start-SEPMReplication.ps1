function Start-SEPMReplication {
    <# TODO update help
    .SYNOPSIS
        Gets a list of all accessible domains
    .DESCRIPTION
        Gets a list of all accessible domains
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

        # [switch]
        # $logs,

        # [switch]
        # $ContentAndPackages
    )

    begin {
        # initialize the configuration
        $test_token = Test-SEPMAccessToken
        if ($test_token -eq $false) {
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
        $builder = New-Object System.UriBuilder($URI)
        $query = [System.Web.HttpUtility]::ParseQueryString($builder.Query)
        foreach ($param in $QueryStrings.GetEnumerator()) {
            $query[$param.Key] = $param.Value
        }
        $builder.Query = $query.ToString()
        $URI = $builder.ToString()

        $params = @{
            Method  = 'POST'
            Uri     = $URI
            headers = $headers
        }
    
        $resp = Invoke-ABRestMethod -params $params
        return $resp
    }
}