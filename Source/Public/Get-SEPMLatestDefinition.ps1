function Get-SEPMLatestDefinition {
    <#
    .SYNOPSIS
        Get AV Def Latest Info
    .DESCRIPTION
        Gets the latest revision information for antivirus definitions from Symantec Security Response.
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPMLatestDefinition

        contentName publishedBySymantec publishedBySEPM
        ----------- ------------------- ---------------
        AV_DEFS     9/4/2023 rev. 2     9/4/2023 rev. 2

        Gets the latest revision information for antivirus definitions from Symantec Security Response.
#>

    begin {
        # initialize the configuration
        $test_token = Test-SEPMAccessToken
        if (-not $test_token){
            Get-SEPMAccessToken | Out-Null
        }
        $URI = $script:BaseURLv1 + "/content/avdef/latest"
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