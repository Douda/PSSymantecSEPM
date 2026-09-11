function Invalidate-SEPMSession {
    <#
    .SYNOPSIS
        Invalidates the cached SEPM session and any API token (in memory and on disk).

    .DESCRIPTION
        Clears the in-memory session cache ($script:_session), the in-memory token
        ($script:accessToken), and the persisted token file, so that the next
        Initialize-SEPMSession call re-authenticates from scratch.

        Distinct from Clear-SEPMAuthentication, which also wipes the credential and
        the credential file. This clears only the session and the token - the
        credential is left in place. Used by the Export-SEPMInventory ExplicitAuth
        bootstrap to force a fresh credential check before a long-running export.
    #>
    [CmdletBinding()]
    param()

    $script:_session = $null
    $script:accessToken = $null
    Remove-Item -Path $script:accessTokenFilePath -Force -ErrorAction SilentlyContinue
}
