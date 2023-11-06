function Get-SEPClientDefVersions {
    <#
    .SYNOPSIS
        Gets a list of clients for a group by content version.
    .DESCRIPTION
        Gets a list of clients for a group by content version.
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPClientDefVersions

        version             clientsCount
        -------             ------------
        2023-09-04 rev. 002           15
        2023-09-03 rev. 002            4
        2023-09-01 rev. 008            2
        2023-08-31 rev. 021            2
        2023-08-31 rev. 002            1
        2023-08-29 rev. 003            1

        Gets a list of clients grouped by content version.
#>

    begin {
        # initialize the configuration
        $test_token = Test-SEPMAccessToken
        if ($test_token -eq $false) {
            Get-SEPMAccessToken | Out-Null
        }
        $URI = $script:BaseURLv1 + "/stats/client/content"
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