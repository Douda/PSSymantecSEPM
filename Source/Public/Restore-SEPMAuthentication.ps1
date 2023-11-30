function Restore-SEPMAuthentication {
    <#
    .SYNOPSIS
        Sets the specified file to be the user's authentication file.

    .DESCRIPTION
        Sets the specified file to be the user's authentication file.

        This is primarily used for unit testing scenarios.
    .PARAMETER Path
        The path to store the user's current authentication file.

    .EXAMPLE
        Restore-SEPMAuthentication -Path 'c:\foo\config.xml'

        Makes the contents of c:\foo\config.xml be the user's authentication for the module.
#>
    [CmdletBinding()]
    param(
        [ValidateScript({
                if (Test-Path -Path $_ -PathType Leaf) { $true }
                else { throw "$_ does not exist." } })]
        [string] $Path,

        [Parameter(ParameterSetName = 'AccessToken')]
        [switch] $AccessToken,

        [Parameter(ParameterSetName = 'Credential')]
        [switch] $Credential
    )
    
    if ($AccessToken) {
        # Make sure that the path that we're going to be storing the file exists.
        $null = New-Item -Path (Split-Path -Path $script:accessTokenFilePath -Parent) -ItemType Directory -Force

        $null = Copy-Item -Path $Path -Destination $script:accessTokenFilePath -Force
    }
    
    if ($Credential) {
        # Make sure that the path that we're going to be storing the file exists.
        $null = New-Item -Path (Split-Path -Path $script:credentialsFilePath -Parent) -ItemType Directory -Force

        $null = Copy-Item -Path $Path -Destination $script:credentialsFilePath -Force
    }

    Initialize-SepmConfiguration
}