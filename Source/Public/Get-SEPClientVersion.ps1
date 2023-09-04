function Get-SEPClientVersion {
    <#
    .SYNOPSIS
        Gets a list and count of clients by client product version.
    .DESCRIPTION
        Gets a list and count of clients by client product version.
    .EXAMPLE
        PS C:\PSSymantecSEPM> $SEPversions = Get-SEPClientVersion
        PS C:\PSSymantecSEPM> $SEPversions.clientVersionList

        version        clientsCount formattedVersion
        -------        ------------ ----------------
        11.0.6000.550             1 11.0.6 (11.0 MR6) build 550
        12.1.2015.2015            1 12.1.2 (12.1 RU2) build 2015
        12.1.6867.6400            1 12.1.6 (12.1 RU6 MP4) build 6867
        12.1.7004.6500            3 12.1.6 (12.1 RU6 MP5) build 7004
        12.1.7454.7000          177 12.1.7 (12.1 RU7) build 7454
        14.0.3752.1000           36 14.0.3 (14.0 RU3 MP7) build 1000
        14.2.1031.0100           21 14.2.1 (14.2 RU1) build 0100
        14.2.3335.1000            3 14.2.3 (14.2 RU3 MP3) build 1000
        14.3.510.0000            12 14.3 (14.3) build 0000
        14.3.558.0000             5 14.3 (14.3) build 0000

        Gets a list and count of clients by client product version.
#>

    begin {
        # initialize the configuration
        $test_token = Test-SEPMAccessToken
        if ($test_token -eq $false) {
            Get-SEPMAccessToken | Out-Null
        }
        $URI = $script:BaseURLv1 + "/stats/client/version"
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