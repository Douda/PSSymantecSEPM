function Backup-SEPMConfiguration {
    <#
    .SYNOPSIS
        Exports the user's current configuration file.

    .DESCRIPTION
        Exports the user's current configuration file.

        This is primarily used for unit testing scenarios.

    .PARAMETER Path
        The path to store the user's current configuration file.

    .PARAMETER Force
        If specified, will overwrite the contents of any file with the same name at the
        location specified by Path.

    .EXAMPLE
        Backup-SEPMConfiguration -Path 'c:\foo\config.json'

        Writes the user's current configuration file to c:\foo\config.json.
#>
    [CmdletBinding()]
    param(
        [string] $Path,

        [switch] $Force
    )

    # Make sure that the path that we're going to be storing the file exists.
    $null = New-Item -Path (Split-Path -Path $Path -Parent) -ItemType Directory -Force

    if (Test-Path -Path $script:configurationFilePath -PathType Leaf) {
        $null = Copy-Item -Path $script:configurationFilePath -Destination $Path -Force:$Force
    } else {
        ConvertTo-Json -InputObject @{} | Set-Content -Path $Path -Force:$Force
    }
}