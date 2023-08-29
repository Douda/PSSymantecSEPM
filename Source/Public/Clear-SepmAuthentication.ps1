function Clear-SepmAuthentication {
    <#
    .SYNOPSIS
        Clears out any API token from memory, as well as from local file storage.

    .DESCRIPTION
        Clears out any API token from memory, as well as from local file storage.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER SessionOnly
        By default, this will clear out the cache in memory, as well as in the local
        configuration file.  If this switch is specified, authentication will be cleared out
        in this session only -- the local configuration file cache will remain
        (and thus still be available in a new PowerShell session).

    .EXAMPLE
        Clear-SepmAuthentication

        Clears out any GitHub API token from memory, as well as from local file storage.

    .NOTES
        This command will not clear your configuration settings.
        Please use Reset-GitHubConfiguration to accomplish that.
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch] $SessionOnly
    )

    Write-InvocationLog

    Set-TelemetryEvent -EventName Clear-SepmAuthentication

    if (-not $PSCmdlet.ShouldProcess('Sepm Authentication', 'Clear')) {
        return
    }

    $script:Credential = $null

    if (-not $SessionOnly) {
        Remove-Item -Path $script:credentialsFilePath -Force -ErrorAction SilentlyContinue -ErrorVariable ev

        if (($null -ne $ev) -and
            ($ev.Count -gt 0) -and
            ($ev[0].FullyQualifiedErrorId -notlike 'PathNotFound*')) {
            $message = "Experienced a problem trying to remove the file that persists the Access Token [$script:credentialsFilePath]."
            Write-Log -Message $message -Level Warning -Exception $ev[0]
        }
    }

    $message = "This has not cleared your configuration settings.  Call Reset-SepmConfiguration to accomplish that."
    Write-Log -Message $message -Level Verbose
}