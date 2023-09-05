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

    begin {
        # initialize the configuration
        $test_token = Test-SEPMAccessToken
        if ($test_token -eq $false) {
            Get-SEPMAccessToken | Out-Null
        }
        $URI = $script:BaseURLv1 + "/stats/threat"
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
        switch ($PSVersionTable.PSVersion.Major) {
            { $_ -ge 6 } { 
                try {
                    if ($script:accessToken.skipCert -eq $true) {
                        $resp = Invoke-RestMethod @params -SkipCertificateCheck
                    } else {
                        $resp = Invoke-RestMethod @params
                    }
                } catch {
                    Write-Warning -Message "Error: $_"
                }
            }
            default {
                try {
                    if ($script:accessToken.skipCert -eq $true) {
                        Skip-Cert
                        $resp = Invoke-RestMethod @params
                    } else {
                        $resp = Invoke-RestMethod @params
                    }
                } catch {
                    Write-Warning -Message "Error: $_"
                }
            }
        }

        # return the response
        return $resp
    }
}