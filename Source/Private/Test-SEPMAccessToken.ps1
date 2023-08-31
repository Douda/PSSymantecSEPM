function Test-SEPMAccessToken {
    <#
    .SYNOPSIS
        Test if the access token is still valid
    .DESCRIPTION
        Test if the access token is still valid

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

    # Check if the access token has expired
    if ($TokenInfo.tokenExpiration -lt (Get-Date)) {
        return $true
    } else {
        return $false
    }
}