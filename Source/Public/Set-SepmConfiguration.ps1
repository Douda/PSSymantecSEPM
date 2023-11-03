function Set-SepmConfiguration {
    <#
    .SYNOPSIS
        Change the value of a configuration property for the PSSymantecSEPM module

    .DESCRIPTION
        Change the value of a configuration property for the PSSymantecSEPM module
        A single call to this method can set any number or combination of properties.

    .PARAMETER ServerAddress
        The hostname of the SEPM instance to communicate with. 

    .EXAMPLE
        Set-SepmConfiguration ServerAddress "MySEPMServer"

        Set the SEPM server address to "MySEPMServer"

#>
    [CmdletBinding(
        PositionalBinding = $false
    )]
    param(
        [string] $ServerAddress,

        [int] $Port
    )

    $persistedConfig = Read-SepmConfiguration -Path $script:configurationFilePath

    $properties = Get-Member -InputObject $script:configuration -MemberType NoteProperty | Select-Object -ExpandProperty Name
    foreach ($name in $properties) {
        if ($PSBoundParameters.ContainsKey($name)) {
            $value = $PSBoundParameters.$name
            if ($value -is [switch]) { $value = $value.ToBool() }
            $script:configuration.$name = $value
            Add-Member -InputObject $persistedConfig -Name $name -Value $value -MemberType NoteProperty -Force
        }
    }

    Save-SepmConfiguration -Configuration $persistedConfig -Path $script:configurationFilePath

}