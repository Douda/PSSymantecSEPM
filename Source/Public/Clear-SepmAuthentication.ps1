function Clear-SepmAuthentication {
    <#
    .SYNOPSIS
        Clears out any API token from memory, as well as from local file storage.

    .DESCRIPTION
        Clears out any API token from memory, as well as from local file storage.

    .EXAMPLE
        Clear-SepmAuthentication

        Clears out any API token from memory, as well as from local file storage.

    .NOTES
        This command will not clear your configuration settings.
        Please use Reset-SepmConfiguration to accomplish that.
#>


    $script:Credential = $null
    $script:accessToken = $null

    if (-not $SessionOnly) {
        Remove-Item -Path $script:credentialsFilePath -Force -ErrorAction SilentlyContinue -ErrorVariable ev
        Remove-Item -Path $script:accessTokenFilePath -Force -ErrorAction SilentlyContinue -ErrorVariable ev

        if (($null -ne $ev) -and
            ($ev.Count -gt 0) -and
            ($ev[0].FullyQualifiedErrorId -notlike 'PathNotFound*')) {
            $message = "Experienced a problem trying to remove the file that persists the Access Token [$script:credentialsFilePath]."
            Write-Warning -Message $message
        }
    }

    $message = "This has not cleared your configuration settings.  Call Reset-SepmConfiguration to accomplish that."
    Write-Verbose -Message $message
}