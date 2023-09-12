function Reset-SEPMConfiguration {
    <#
    .SYNOPSIS
        Clears out the user's configuration file and configures this session with all default
        configuration values.

    .DESCRIPTION
        Clears out the user's configuration file and configures this session with all default
        configuration values.

    .EXAMPLE
        Reset-SEPMConfiguration

        Deletes the local configuration file and loads in all default configuration values.

    .NOTES
        This command will not clear your authentication token.
        Please use Clear-SEPMAuthentication to accomplish that.
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch] $SessionOnly
    )

    if (-not $PSCmdlet.ShouldProcess('Sepm Configuration', 'Reset')) {
        return
    }

    $null = Remove-Item -Path $script:configurationFilePath -Force -ErrorAction SilentlyContinue -ErrorVariable ev

    if (($null -ne $ev) -and ($ev.Count -gt 0) -and ($ev[0].FullyQualifiedErrorId -notlike 'PathNotFound*')) {
        $message = "Reset was unsuccessful.  Experienced a problem trying to remove the file [$script:configurationFilePath]."
        Write-Warning -Message $message
    }
    

    Initialize-SepmConfiguration

    $message = "This has not cleared your authentication token.  Call Clear-SEPMAuthentication to accomplish that."
    Write-Verbose -Message $message
}