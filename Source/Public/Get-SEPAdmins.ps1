Function Get-SEPAdmins {
    <#
    .SYNOPSIS
        Displays a list of admins in the Symantec Database

    .DESCRIPTION
        Gets the list of administrators for a particular domain.

        The Git repo for this module can be found here: https://github.com/Douda/PSSymantecSEPM

    .PARAMETER AdminName
        Displays only a specific user from the Admin List

    .EXAMPLE
    Get-SEPAdmins -AdminName admin

    .EXAMPLE
    Get-SEPAdmins
#>
    [CmdletBinding()]
    Param (
        # AdminName
        [Parameter(
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [String]
        [Alias("Admin", "AdminName")]
        $AdminName
    )

    begin {
        # initialize the configuration
        $test_token = Test-SEPMAccessToken
        if ($test_token -eq $false) {
            Get-SEPMAccessToken
        }
        $URI = $script:BaseURL + "/admin-users"
        $headers = @{
            "Authorization" = "Bearer " + $script:accessToken.token
            "Content"       = 'application/json'
        }
    }

    process {
        # URI query strings
        $QueryStrings = @{
            domain = $script:configuration.domain
        }

        # Contruct the URI
        $builder = New-Object System.UriBuilder($URI)
        $query = [System.Web.HttpUtility]::ParseQueryString($builder.Query)
        foreach ($param in $QueryStrings.GetEnumerator()) {
            $query[$param.Key] = $param.Value
        }
        $builder.Query = $query.ToString()
        $URI = $builder.ToString()

        # Invoke the request
        # If the version of PowerShell is 6 or greater, then we can use the -SkipCertificateCheck parameter
        # else we need to use the Skip-Cert function if self-signed certs are being used.
        switch ($PSVersionTable.PSVersion.Major) {
            { $_ -ge 6 } { 
                try {
                    $params = @{
                        Method  = 'GET'
                        Uri     = $URI
                        headers = $headers
                    }
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

        # Process the response
        if ([string]::IsNullOrEmpty($AdminName)) {
            return $resp
        } else {
            $resp = $resp | Where-Object { $_.loginName -eq $AdminName }
            return $resp
        }
    }
}