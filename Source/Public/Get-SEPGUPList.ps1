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

    begin {
        # initialize the configuration
        $test_token = Test-SEPMAccessToken
        if ($test_token -eq $false) {
            Get-SEPMAccessToken | Out-Null
        }
        $URI = $script:BaseURLv1 + "/gup/status"
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