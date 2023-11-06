function Get-SEPMGroups {
    <#
    .SYNOPSIS
        Gets a group list
    .DESCRIPTION
        Gets a group list
    .EXAMPLE
        PS C:\GitHub_Projects\PSSymantecSEPM> Get-SEPMGroups | Select-Object -First 1 

        id                        : XXXXXXXXXXXXXXXXXXXXXXXXX
        name                      : My Company
        description               : 
        fullPathName              : My Company
        numberOfPhysicalComputers : 0
        numberOfRegisteredUsers   : 0
        createdBy                 : XXXXXXXXXXXXXXXXXXXXXXXXX
        created                   : 1360247401336
        lastModified              : 1639056401576
        policySerialNumber        : 718B-09/04/2023 12:56:58 775
        policyDate                : 1693832218775
        customIpsNumber           : 
        domain                    : @{id=XXXXXXXXXXXXXXXXXXXXXXXXX; name=Default}
        policyInheritanceEnabled  : False

        Gets the first group of the list of groups
#>

    begin {
        # initialize the configuration
        $test_token = Test-SEPMAccessToken
        if ($test_token -eq $false) {
            Get-SEPMAccessToken | Out-Null
        }
        $URI = $script:BaseURLv1 + "/groups"
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
    
        # Invoke the request
        # If the version of PowerShell is 6 or greater, then we can use the -SkipCertificateCheck parameter
        # else we need to use the Skip-Cert function if self-signed certs are being used.
        do {
            try {
                # Invoke the request params
                $params = @{
                    Method  = 'GET'
                    Uri     = $URI
                    headers = $headers
                }
                
                $resp = Invoke-ABRestMethod -params $params
                
                # Process the response
                $allResults += $resp.content

                # Increment the page index & update URI
                $QueryStrings.pageIndex++
                $query = [System.Web.HttpUtility]::ParseQueryString($builder.Query)
                foreach ($param in $QueryStrings.GetEnumerator()) {
                    $query[$param.Key] = $param.Value
                }
                $builder.Query = $query.ToString()
                $URI = $builder.ToString()
            } catch {
                Write-Warning -Message "Error: $_"
            }
        } until ($resp.lastPage -eq $true)

        # return the response
        return $allResults
    }
}