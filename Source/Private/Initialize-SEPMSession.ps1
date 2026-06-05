function Initialize-SEPMSession {
    <#
    .SYNOPSIS
        Initializes a SEPM API session, handling the full token lifecycle.

    .DESCRIPTION
        Checks for a cached session in $script:_session. If valid, returns it immediately.
        Otherwise, goes through the token acquisition flow (check memory → check disk →
        query SEPM → cache to memory and disk) and returns a session context object
        with Headers, BaseURLv1, BaseURLv2, and SkipCert.

    .OUTPUTS
        PSCustomObject with Headers, BaseURLv1, BaseURLv2, SkipCert properties.

    .NOTES
        Internal helper method. Not exported.
    #>
    [CmdletBinding()]
    param()

    # Validate that the module is configured
    if ([String]::IsNullOrEmpty($script:configuration.ServerAddress)) {
        $message = 'SEPM Server address is not configured. Use Set-SepmConfiguration -ServerAddress <address> to configure.'
        Write-Error -Message $message -ErrorAction Stop
    }

    # Check cached session
    if ($script:_session) {
        if (Test-SEPMAccessToken -Token $script:_session.TokenInfo) {
            return $script:_session
        }
    }

    # Acquire a token (delegates to the existing token lifecycle)
    $tokenInfo = Get-SEPMAccessToken

    # Build the session object
    $script:_session = [PSCustomObject]@{
        Headers   = @{
            Authorization = "Bearer $($tokenInfo.token)"
            Content       = 'application/json'
        }
        BaseURLv1 = $script:BaseURLv1
        BaseURLv2 = $script:BaseURLv2
        SkipCert  = $script:SkipCert
        TokenInfo = $tokenInfo
    }

    return $script:_session
}
