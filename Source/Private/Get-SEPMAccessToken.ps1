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

        A rejected credential, an unreachable server or an untrusted certificate all mean no
        token comes back. Each is raised as a Transport Error here rather than cached, so the
        failure is named at the point it happens instead of surfacing later as "invalid_token"
        on every subsequent call. The cached token file is treated as a cache: if it is empty
        or unreadable it is discarded and authentication simply runs again.

    .PARAMETER AccessToken
        If provided, this will be returned instead of using the cached/configured value

    .OUTPUTS
        System.Management.Automation.PSCustomObject (token, tokenExpiration, SkipCert)
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

    # If still not found, will look to see if there is a file with the API token stored on disk.
    # This file is a cache: if it is empty or unreadable, drop it and authenticate again rather
    # than failing. Import-Clixml on a zero-byte file throws "Root element is missing.", and
    # -ErrorAction Ignore does not suppress that.
    if (Test-Path $script:accessTokenFilePath) {
        $AccessToken = $null
        if ((Get-Item -Path $script:accessTokenFilePath).Length -eq 0) {
            Write-Verbose "Cached access token file is empty, discarding it: $script:accessTokenFilePath"
            Remove-Item -Path $script:accessTokenFilePath -Force -ErrorAction SilentlyContinue
        } else {
            try {
                $AccessToken = Import-Clixml -Path $script:accessTokenFilePath -ErrorAction Stop
            } catch {
                Write-Verbose "Cached access token file is unreadable, discarding it: $($_.Exception.Message)"
                Remove-Item -Path $script:accessTokenFilePath -Force -ErrorAction SilentlyContinue
                $AccessToken = $null
            }
        }
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
        Set-SEPMConfiguration -ServerAddress $ServerAddress
    }

    # Look for credentials stored on disk. Unlike the token, this file holds a real secret, so
    # corruption is reported rather than swallowed: treat the file as absent and let the prompt
    # below ask for the credential again.
    if (Test-Path $script:credentialsFilePath) {
        if ((Get-Item -Path $script:credentialsFilePath).Length -eq 0) {
            Write-Warning "Stored credential file is empty and will be ignored: $script:credentialsFilePath"
        } else {
            try {
                $script:Credential = Import-Clixml -Path $script:credentialsFilePath -ErrorAction Stop
            } catch {
                Write-Warning "Stored credential file could not be read and will be ignored: $($_.Exception.Message)"
            }
        }
    }
    if ($null -eq $script:Credential) {
        $message = "Credentials not found. Provide credentials :"
        Write-Warning -Message $message
        Set-SEPMAuthentication -credential (Get-Credential)
    }

    # Construct the request
    $URI_Authenticate = $script:BaseURLv1 + '/identity/authenticate'
    $body = @{
        "username" = $script:Credential.UserName
        "password" = ([System.Net.NetworkCredential]::new("", $script:Credential.Password).Password)
        "appName"  = "PSSymantecSEPM PowerShell Module"
        "domain"   = $script:configuration.domain
    }

    # Invoke the request and SkipCert if needed (Manual parameter set — no session exists yet)
    try {
        $Response = Invoke-SepmApi -Method POST -Uri $URI_Authenticate `
            -Body (ConvertTo-SEPMJson -InputObject $body) -ContentType 'application/json' `
            -Headers @{} -SkipCert $script:SkipCert
    } catch {
        # Anything that goes wrong on /identity/authenticate is an authentication failure as far
        # as the caller is concerned - SEPM answers a wrong password with a generic 400, so the
        # transport cannot tell. The one exception is a certificate that could not be validated:
        # the transport already tagged that with the more precise remedy, so it passes through.
        if ($_.FullyQualifiedErrorId -like 'SEPM.CertificateError*') {
            throw
        }
        $PSCmdlet.ThrowTerminatingError((New-SEPMApiError -Message $_.Exception.Message `
                    -ErrorId 'SEPM.AuthenticationFailed' `
                    -Category ([System.Management.Automation.ErrorCategory]::AuthenticationError) `
                    -Target $URI_Authenticate))
    }

    # A response carrying no token is not a successful authentication. Without this check the
    # module would cache a null token, report success, and leave every later call to fail with
    # "invalid_token" instead of naming the real problem.
    if ([String]::IsNullOrEmpty($Response.token)) {
        $message = "SEPM authentication failed for user '$($script:Credential.UserName)'. The server did not return an access token."
        $PSCmdlet.ThrowTerminatingError((New-SEPMApiError -Message $message `
                    -ErrorId 'SEPM.AuthenticationFailed' `
                    -Category ([System.Management.Automation.ErrorCategory]::AuthenticationError) `
                    -Target $URI_Authenticate))
    }

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