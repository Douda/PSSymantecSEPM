function Test-SEPMAccessToken {
    <#
    .SYNOPSIS
        Test if the access token is still valid
    .DESCRIPTION
        Test if the access token is still valid.
        If no token is passed, will test the cached token.

        Returns $true if the token is still valid, $false otherwise
    .PARAMETER TokenInfo
        The token to test
    .OUTPUTS
        System.Boolean
    .NOTE
        Internal helper method.
        This function is used internally by the module and should not be called directly.
    #>
    
    
    param (
        [Alias('AccessToken', 'Token')]
        [PSCustomObject]$TokenInfo
    )

    # If no paramater is passed, test the cached token
    if ($null -eq $TokenInfo) {
        # if token in memory
        if (-not [string]::IsNullOrEmpty($script:accessToken.token) ) {
            # if token still valid
            if ($script:accessToken.tokenExpiration -gt (Get-Date)) {
                return $true
            } 
        }
    }

    # Check if the access token has expired
    if ($TokenInfo.tokenExpiration -gt (Get-Date)) {
        return $true
    }

    # If we get here, no valid token was found
    return $false
}