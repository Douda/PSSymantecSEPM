function Initialize-SEPMSession {
    <#
    .SYNOPSIS
        Validates the access token, applies the SkipCertificateCheck override,
        and returns a session context object with headers and base URLs.
    .DESCRIPTION
        Checks whether the current access token is still valid. If expired,
        refreshes it via Get-SEPMAccessToken. Applies the -SkipCertificateCheck
        flag to $script:SkipCert if requested. Returns a PSCustomObject with
        Headers, BaseURLv1, and BaseURLv2 for use by other cmdlets.
    .PARAMETER SkipCertificateCheck
        If specified, sets $script:SkipCert = $true to bypass certificate
        validation for self-signed SEPM certificates.
    .OUTPUTS
        PSCustomObject with properties:
        - Headers (hashtable): Authorization and Content headers
        - BaseURLv1 (string): SEPM API v1 base URL
        - BaseURLv2 (string): SEPM API v2 base URL
    .NOTE
        Internal helper method.
        This function is used internally by the module and should not be called directly.
    #>

    [CmdletBinding()]
    param (
        [Parameter()]
        [switch]
        $SkipCertificateCheck
    )

    # Validate/renew access token
    $test_token = Test-SEPMAccessToken
    if (-not $test_token) {
        Get-SEPMAccessToken | Out-Null
    }

    # Apply SkipCert override if requested
    if ($SkipCertificateCheck) {
        $script:SkipCert = $true
    }

    # Build and return session context
    return [PSCustomObject]@{
        Headers   = @{
            'Authorization' = "Bearer $($script:accessToken.token)"
            'Content'       = 'application/json'
        }
        BaseURLv1 = $script:BaseURLv1
        BaseURLv2 = $script:BaseURLv2
    }
}
