function Reset-SepmConfiguration {
    <#
    .SYNOPSIS
        Clears out the user's configuration file and configures this session with all default
        configuration values.

    .DESCRIPTION
        Clears out the user's configuration file and configures this session with all default
        configuration values.

        This would be the functional equivalent of using this on a completely different computer.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER SessionOnly
        By default, this will delete the location configuration file so that all defaults are used
        again.  If this is specified, then only the configuration values that were made during
        this session will be discarded.

    .EXAMPLE
        Reset-SepmConfiguration

        Deletes the local configuration file and loads in all default configuration values.

    .NOTES
        This command will not clear your authentication token.
        Please use Clear-GitHubAuthentication to accomplish that.
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch] $SessionOnly
    )

    if (-not $PSCmdlet.ShouldProcess('Sepm Configuration', 'Reset')) {
        return
    }

    Set-TelemetryEvent -EventName Reset-SepmConfiguration

    if (-not $SessionOnly) {
        $null = Remove-Item -Path $script:configurationFilePath -Force -ErrorAction SilentlyContinue -ErrorVariable ev

        if (($null -ne $ev) -and ($ev.Count -gt 0) -and ($ev[0].FullyQualifiedErrorId -notlike 'PathNotFound*')) {
            $message = "Reset was unsuccessful.  Experienced a problem trying to remove the file [$script:configurationFilePath]."
            # Write-Log -Message $message -Level Warning -Exception $ev[0]
        }
    }

    Initialize-SepmConfiguration

    $message = "This has not cleared your authentication token.  Call Clear-GitHubAuthentication to accomplish that."
    # Write-Log -Message $message -Level Verbose
}