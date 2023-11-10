function Set-SepmConfiguration {
    <#
    .SYNOPSIS
        Change the value of a configuration property for the PSSymantecSEPM module

    .DESCRIPTION
        Change the value of a configuration property for the PSSymantecSEPM module
        A single call to this method can set any number or combination of properties.

    .PARAMETER ServerAddress
        The hostname of the SEPM instance to communicate with. 
    .PARAMETER Port
        The port number of the SEPM instance to communicate with.
    .EXAMPLE
        Set-SepmConfiguration -ServerAddress "MySEPMServer"

        Set the SEPM server address to "MySEPMServer"
    .EXAMPLE
        Set-SepmConfiguration -ServerAddress "MySEPMServer" -Port 8446

        Set the SEPM server address to "MySEPMServer" and the port to 8446


#>
    [CmdletBinding(
        PositionalBinding = $false
    )]
    param(
        [string] $ServerAddress,

        [int] $Port
    )

    # Load in the persisted configuration object
    $persistedConfig = Read-SepmConfiguration -Path $script:configurationFilePath

    # Update the configuration object with any values that were provided as parameters
    $properties = Get-Member -InputObject $script:configuration -MemberType NoteProperty | Select-Object -ExpandProperty Name

    # $PSBoundParameters is a hashtable of all the parameters that were passed to this function
    # We can use this to determine which properties were passed in and update the configuration object
    # Allows to easily add new properties by adding a param function without having to update this function
    foreach ($name in $properties) {
        if ($PSBoundParameters.ContainsKey($name)) {
            $value = $PSBoundParameters.$name
            if ($value -is [switch]) { $value = $value.ToBool() }
            $script:configuration.$name = $value
            Add-Member -InputObject $persistedConfig -Name $name -Value $value -MemberType NoteProperty -Force
        }
    }

    # Persist the configuration object to disk
    Save-SepmConfiguration -Configuration $persistedConfig -Path $script:configurationFilePath

}