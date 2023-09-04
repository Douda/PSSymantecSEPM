Function Get-SEPMVersion {
    <# TODO update help
    .SYNOPSIS
        A short one-line action-based description, e.g. 'Tests if a function is valid'
    .DESCRIPTION
        A longer description of the function, its purpose, common use cases, etc.
    .NOTES
        Information or caveats about the function e.g. 'This function is not supported in Linux'
    .LINK
        Specify a URI to a help page, this will show when Get-Help -Online is used.
    .EXAMPLE
        Test-MyTestFunction -Verbose
        Explanation of the function or its result. You can include multiple examples with additional .EXAMPLE lines
    #>
    

    # initialize the configuration
    $test_token = Test-SEPMAccessToken
    if ($test_token -eq $false) {
        Get-SEPMAccessToken
    }
    $URI = $script:BaseURL + "/version"
    $headers = @{
        "Authorization" = "Bearer " + $script:accessToken.token
        "Content"       = 'application/json'
    }
    $body = @{
    }
    $params = @{
        Method  = 'GET'
        Uri     = $URI
        headers = $headers
        Body    = ($body | ConvertTo-Json)
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
                "An error was found with this command. Please review the resultant error for details."
                $RESTError = Get-RestError($_)
                "Errors: $RESTError"
            }
        }
    }

    return $resp
}