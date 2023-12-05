function Get-SEPMAccessToken {
    <# 
    .SYNOPSIS
        Retrieves the API token for use in the rest of the module.

    .DESCRIPTION
        Retrieves the API token for use in the rest of the module.

        First will try to use the one that may have been provided as a parameter.
        If not provided, then will try to use the one already cached in memory.
        If still not found, will look to see if there is a file with the API token stored on disk
        Finally, if there is still no available token :
            - check if the SEPM server name is configured
            - check if the credentials are configured or stored on disk
            - query one from the SEPM server
            - store it in memory and on disk
            - return the token

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

    # Test if the SEPM server name is configured
    if ($null -eq $script:configuration.ServerAddress) {
        $message = "SEPM Server name not found. Provide server name :"
        Write-Warning -Message $message
        $ServerAddress = Read-Host -Prompt $message
        Set-SepmConfiguration -ServerAddress $ServerAddress
    }

    # Look for credentials stored in the disk
    if (Test-Path $script:credentialsFilePath) {
        $script:Credential = Import-Clixml -Path $script:credentialsFilePath
    }
    if ($null -eq $script:Credential) {
        $message = "Credentials not found. Provide credentials :"
        Write-Warning -Message $message
        Set-SEPMAuthentication -credential (Get-Credential)
    }

    # Test the certificate of the SEPM server
    $URI_Authenticate = $script:BaseURLv1 + '/identity/authenticate'
    Test-SEPMCertificate -URI $URI_Authenticate

    # Construct the request
    $body = @{
        "username" = $script:Credential.UserName
        "password" = ([System.Net.NetworkCredential]::new("", $script:Credential.Password).Password)
        "appName"  = "PSSymantecSEPM PowerShell Module"
        "domain"   = $script:configuration.domain
    }

    $Params = @{
        Method      = 'POST'
        Uri         = $URI_Authenticate
        ContentType = "application/json"
        Body        = ($body | ConvertTo-Json)
    }

    # Invoke the request and SkipCert if needed
    $Response = Invoke-ABRestMethod -params $Params

    # Sort the response
    $CachedToken = [PSCustomObject]@{
        token           = $response.token
        tokenExpiration = (Get-Date).AddSeconds($Response.tokenExpiration)
        SkipCert        = $script:SkipCert
    }

    # Caches the token in memory
    $script:accessToken = $CachedToken

    # Stores it in a file on disk as a SecureString
    if (-not (Test-Path ($Script:accessTokenFilePath | Split-Path))) {
        New-Item -ItemType Directory -Path ($Script:accessTokenFilePath | Split-Path) -Force | Out-Null
    }
    $script:accessToken | Export-Clixml -Path $script:accessTokenFilePath -Force

    # return the token
    return $script:accessToken
}