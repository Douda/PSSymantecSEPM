function Get-SepmAccessToken {
    <# TODO update this to use the new Get-SEPToken function
    .SYNOPSIS
        Retrieves the API token for use in the rest of the module.

    .DESCRIPTION
        Retrieves the API token for use in the rest of the module.

        First will try to use the one that may have been provided as a parameter.
        If not provided, then will try to use the one already cached in memory.
        If still not found, will look to see if there is a file with the API token stored on disk
        Finally, if there is still no available token, query one from the SEPM server.

    .PARAMETER AccessToken
        If provided, this will be returned instead of using the cached/configured value

    .OUTPUTS
        System.String
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [PSCustomObject] $AccessToken
    )

    # First will try to use the one that may have been provided as a parameter.
    if (-not [String]::IsNullOrEmpty($AccessToken.token)) {
        if (Test-SEPMAccessToken -Token $AccessToken) {
            $script:accessToken = $AccessToken
            return $AccessToken
        }
    }

    # If not provided, then will try to use the one already cached in memory.
    if (-not [String]::IsNullOrEmpty($script:accessToken)) {
        if (Test-SEPMAccessToken -Token $script:accessToken) {
            return $script:accessToken
        }
    }

    # If still not found, will look to see if there is a file with the API token stored in the disk
    if (Test-Path $script:accessTokenFilePath) {
        $AccessToken = Import-Clixml -Path $script:accessTokenFilePath -ErrorAction Ignore
        if (Test-SEPMAccessToken -Token $AccessToken) {
            $script:accessToken = $AccessToken
            return $script:accessToken
        }
    }
        
    # Finally, if there is still no available token, query one from the SEPM server.
    # Then caches the token in memory and stores it in a file on disk as a SecureString
    if ($null -eq $script:configuration.ServerAddress) {
        $message = "SEPM Server name not found. Use Set-SepmConfiguration to update it and try again"
        Write-Warning -Message $message
        throw $message
    }
    
    if ($null -eq $script:Credential) {
        $script:Credential = Get-Credential
    }

    $body = @{
        "username" = $script:Credential.UserName
        "password" = ([System.Net.NetworkCredential]::new("", $script:Credential.Password).Password)
        "appName"  = "PSSymantecSEPM PowerShell Module"
        "domain"   = $script:configuration.domain
    }

    $URI_Authenticate = $script:BaseURL + '/identity/authenticate'
    try {
        Invoke-WebRequest $script:BaseURL
    } catch {
        'SSL Certificate test failed, skipping certificate validation. Please check your certificate settings and verify this is a legitimate source.'
        $Response = Read-Host -Prompt 'Please press enter to ignore this and continue without SSL/TLS secure channel'
        if ($Response -eq "") {
            if ($PSVersionTable.PSVersion.Major -lt 6) {
                Skip-Cert
                $script:SkipCert = $true
            }
            if ($PSVersionTable.PSVersion.Major -ge 6) {
                $script:SkipCert = $true
            }
        }
    }

    try {
        $Params = @{
            Method      = 'POST'
            Uri         = $URI_Authenticate
            ContentType = "application/json"
            Body        = ($body | ConvertTo-Json)
        }
        if ($PSVersionTable.PSVersion.Major -lt 6) {
            $Response = Invoke-RestMethod @Params
        }
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            if ($script:SkipCert -eq $true) {
                $Response = Invoke-RestMethod @Params -SkipCertificateCheck
            } else {
                $Response = Invoke-RestMethod @Params
            }
        }
    } catch {
        Get-RestErrorDetails
    }

    # Caches the token in memory and stores token information & expiration in a file on disk 
    $CachedToken = [PSCustomObject]@{
        token           = $response.token
        tokenExpiration = (Get-Date).AddSeconds($Response.tokenExpiration)
        SkipCert        = $script:SkipCert
    }
    $script:accessToken = $CachedToken

    if (-not (Test-Path ($Script:accessTokenFilePath | Split-Path))) {
        New-Item -ItemType Directory -Path ($Script:accessTokenFilePath | Split-Path) -Force | Out-Null
    }
    $script:accessToken | Export-Clixml -Path $script:accessTokenFilePath -Force
    return $script:accessToken
}