function Restore-SEPMConfiguration {
    <#
    .SYNOPSIS
        Sets the specified file to be the user's configuration file.

    .DESCRIPTION
        Sets the specified file to be the user's configuration file.

        This is primarily used for unit testing scenarios.
    .PARAMETER Path
        The path to store the user's current configuration file.

    .EXAMPLE
        Restore-SEPMConfiguration -Path 'c:\foo\config.json'

        Makes the contents of c:\foo\config.json be the user's configuration for the module.
#>
    [CmdletBinding()]
    param(
        [ValidateScript({
                if (Test-Path -Path $_ -PathType Leaf) { $true }
                else { throw "$_ does not exist." } })]
        [string] $Path
    )

    # Make sure that the path that we're going to be storing the file exists.
    $null = New-Item -Path (Split-Path -Path $script:configurationFilePath -Parent) -ItemType Directory -Force

    $null = Copy-Item -Path $Path -Destination $script:configurationFilePath -Force

    Initialize-SepmConfiguration
}