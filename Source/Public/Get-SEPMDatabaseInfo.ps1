function Get-SEPMDatabaseInfo {
    <#
    .SYNOPSIS
        Gets the database infromation of local site.
    .DESCRIPTION
        Gets the database infromation of local site : SQL or embedded database, DBUser, database...
    .INPUTS
        None
    .OUTPUTS
        System.Object
    .EXAMPLE
        Get-SEPMDatabaseInfo

        Gets detailed information on the database of the local site 
    #>
    
    # initialize the configuration
    $test_token = Test-SEPMAccessToken
    if ($test_token -eq $false) {
        Get-SEPMAccessToken | Out-Null
    }
    $URI = $script:BaseURLv1 + "/admin/database"
    $headers = @{
        "Authorization" = "Bearer " + $script:accessToken.token
        "Content"       = 'application/json'
    }
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

    return $resp

}