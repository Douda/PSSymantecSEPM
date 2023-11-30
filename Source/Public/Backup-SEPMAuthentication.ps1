function Backup-SEPMAuthentication {
    <#
    .SYNOPSIS
        Exports the user's current authentication file.

    .DESCRIPTION
        Exports the user's current authentication file.

        This is primarily used for unit testing scenarios.

    .PARAMETER Path
        The path to store the user's current authentication file.

    .PARAMETER Force
        If specified, will overwrite the contents of any file with the same name at the
        location specified by Path.

    .EXAMPLE
        Backup-SEPMAuthentication -Path 'c:\foo\credentials.xml'

        Writes the user's current authentication file to c:\foo\credentials.xml.
#>
    [CmdletBinding()]
    param(
        [string] $Path,

        [switch] $Force,

        [switch] $Credentials,

        [switch] $AccessToken
    )

    # Make sure that the path that we're going to be storing the file exists.
    $null = New-Item -Path (Split-Path -Path $Path -Parent) -ItemType Directory -Force

    if ($Credentials) {
        if (Test-Path -Path $script:credentialsFilePath -PathType Leaf) {
            $null = Copy-Item -Path $script:credentialsFilePath -Destination $Path -Force:$Force
        }
    }

    if ($AccessToken) {
        if (Test-Path -Path $script:accessTokenFilePath -PathType Leaf) {
            $null = Copy-Item -Path $script:accessTokenFilePath -Destination $Path -Force:$Force
        }
    }
}