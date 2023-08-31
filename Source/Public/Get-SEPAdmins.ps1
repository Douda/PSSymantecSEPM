Function Get-SEPAdmins {
    <#
.SYNOPSIS
Displays a list of admins in the Symantec Database
.EXAMPLE
Get-SEPAdmins
 
.PARAMETER AdminName
Displays only a specific user from the Admin List
Get-SEPAdmins -AdminName admin
 
.EXAMPLE
Get-SEPAdmins
 
.NOTES
General notes
#>
    [CmdletBinding()]
    Param (
        # AdminName
        [Parameter()]
        [String]
        $AdminName
    )

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
                # if ($script:SkipCert -eq $true) {
                if ($script:accessToken.skipCert -eq $true) {
                    $resp = Invoke-RestMethod @params -SkipCertificateCheck
                } else {
                    $resp = Invoke-RestMethod @params
                }
            } catch {
                "An error was found with this command. Please review the resultant error for details."
                $RESTError = Get-RestError($_)
                "Errors: $RESTError"
            }
        }
        default {
            # if ($script:SkipCert -eq $true) {
            if ($script:accessToken.skipCert -eq $true) {
                Skip-Cert
                $resp = Invoke-RestMethod @params
            } else {
                $resp = Invoke-RestMethod @params
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