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

    begin {
        # initialize the configuration
        $test_token = Test-SEPMAccessToken
        if ($test_token -eq $false) {
            Get-SEPMAccessToken | Out-Null
        }
        $URI = $script:BaseURLv1 + "/stats/client/onlinestatus"
        $headers = @{
            "Authorization" = "Bearer " + $script:accessToken.token
            "Content"       = 'application/json'
        }
    }

    process {
        # URI query strings
        $QueryStrings = @{}

        # Construct the URI
        $builder = New-Object System.UriBuilder($URI)
        $query = [System.Web.HttpUtility]::ParseQueryString($builder.Query)
        foreach ($param in $QueryStrings.GetEnumerator()) {
            $query[$param.Key] = $param.Value
        }
        $builder.Query = $query.ToString()
        $URI = $builder.ToString()

        $params = @{
            Method  = 'GET'
            Uri     = $URI
            headers = $headers
        }
    
        $resp = Invoke-ABRestMethod -params $params
        return $resp
    }
}