function Get-SepmAccessToken {
    <# TODO update this to use the new Get-SEPToken function
    .SYNOPSIS
        Retrieves the API token for use in the rest of the module.

    .DESCRIPTION
        Retrieves the API token for use in the rest of the module.

        First will try to use the one that may have been provided as a parameter.
        If not provided, then will try to use the one already cached in memory.
        If still not found, will look to see if there is a file with the API token stored
        as a SecureString.
        Finally, if there is still no available token, query one from the SEPM server.

    .PARAMETER AccessToken
        If provided, this will be returned instead of using the cached/configured value

    .OUTPUTS
        System.String
#>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidGlobalVars", "", Justification = "For back-compat with v0.1.0, this still supports the deprecated method of using a global variable for storing the Access Token.")]
    [OutputType([String])]
    param(
        [string] $AccessToken
    )

    # First will try to use the one that may have been provided as a parameter.
    if (-not [String]::IsNullOrEmpty($AccessToken)) {
        return $AccessToken
    }

    # If not provided, then will try to use the one already cached in memory.
    if ($null -ne $script:accessToken) {
        $token = $script:accessToken.GetNetworkCredential().Password

        if (-not [String]::IsNullOrEmpty($token)) {
            return $token
        }
    }

    # If still not found, will look to see if there is a file with the API token stored as a SecureString.
    $content = Get-Content -Path $script:accessTokenFilePath -ErrorAction Ignore
    if (-not [String]::IsNullOrEmpty($content)) {
        try {
            $secureString = $content | ConvertTo-SecureString

            $message = "Restoring Access Token from file.  This value can be cleared in the future by calling Clear-GitHubAuthentication."
            Write-Log -Message $messsage -Level Verbose
            $script:accessToken = New-Object System.Management.Automation.PSCredential "<username is ignored>", $secureString
            return $script:accessToken.GetNetworkCredential().Password
        } catch {
            $message = 'The Access Token file for this module contains an invalid SecureString (files can''t be shared by users or computers).  Use Set-SepmAuthentication to update it.'
            Write-Log -Message $message -Level Warning
        }
    }

    # Finally, if there is still no available token, query one from the SEPM server.
    if ($null -eq $BaseURL) {
        "Please enter your symantec server's name and port."
        "(e.g. <sepservername>:8446)"
        $ServerAddress = Read-Host -Prompt "SEPM Server address"
        $script:BaseURL = "https://" + $ServerAddress + '/sepm/api/v1'
    }
    if ($null -eq $script:Credential) {
        $script:Credential = Get-Credential
    }
    $body = @{
        "username" = $script:Credential.UserName
        "password" = ([System.Net.NetworkCredential]::new("", $script:Credential.Password).Password)
        "domain"   = ""
    }
    if ($null -ne $body) {
        $URI = $BaseURL + '/identity/authenticate'
        try {
            Invoke-WebRequest $BaseURL
        } catch {
            'SSL Certificate test failed, skipping certificate validation. Please check your certificate settings and verify this is a legitimate source.'
            $Response = Read-Host -Prompt 'Please press enter to ignore this and continue without SSL/TLS secure channel'
            if ($Response -eq "") {
                if ($PSVersionTable.PSVersion.Major -lt 6) {
                    Skip-Cert
                }
                if ($PSVersionTable.PSVersion.Major -ge 6) {
                    $Global:SkipCert = $true
                }
            }
        }
        try {
            if ($PSVersionTable.PSVersion.Major -lt 6) {
                $SEPToken = (Invoke-RestMethod -Method POST -Uri $URI -ContentType "application/json" -Body ($body | ConvertTo-Json)).token
            }
            if ($PSVersionTable.PSVersion.Major -ge 6) {
                if ($Global:SkipCert -eq $true) {
                    $SEPToken = (Invoke-RestMethod -Method POST -Uri $URI -ContentType "application/json" -Body ($body | ConvertTo-Json) -SkipCertificateCheck).token
                } else {
                    $SEPToken = (Invoke-RestMethod -Method POST -Uri $URI -ContentType "application/json" -Body ($body | ConvertTo-Json) -SkipCertificateCheck).token
                }
            }
        } catch {
            Get-RestErrorDetails
        }
    }
    $script:accessToken = New-Object System.Management.Automation.PSCredential "<username is ignored>", $SEPToken
}