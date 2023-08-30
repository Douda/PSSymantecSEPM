function Import-SepmConfiguration {
    <#
    .SYNOPSIS
        Loads in the default configuration values, and then updates the individual properties
        with values that may exist in a file.

    .DESCRIPTION
        Loads in the default configuration values, and then updates the individual properties
        with values that may exist in a file.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER Path
        The file that may or may not exist with a serialized version of the configuration
        values for this module.

    .OUTPUTS
        PSCustomObject

    .NOTES
        Internal helper method.
        No side-effects.

    .EXAMPLE
        Import-SepmConfiguration -Path 'c:\foo\config.json'

        Creates a new default config object and updates its values with any that are found
        within a deserialized object from the content in $Path.  The configuration object
        is then returned.
#>
    [CmdletBinding()]
    param(
        [string] $Path
    )

    # Create a configuration object with all the default values.  We can then update the values
    # with any that we find on disk.

    $config = [PSCustomObject]@{
        'ServerAddress' = ''
        'port'          = '8446'
    }

    $jsonObject = Read-SepmConfiguration -Path $Path
    Get-Member -InputObject $config -MemberType NoteProperty |
        ForEach-Object {
            $name = $_.Name
            $type = $config.$name.GetType().Name
            $config.$name = Resolve-PropertyValue -InputObject $jsonObject -Name $name -Type $type -DefaultValue $config.$name
        }

    return $config
}
