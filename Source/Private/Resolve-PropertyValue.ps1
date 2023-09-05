function Resolve-PropertyValue {
    <#
    .SYNOPSIS
        Returns the requested property from the provided object, if it exists and is a valid
        value.  Otherwise, returns the default value.

    .DESCRIPTION
        Returns the requested property from the provided object, if it exists and is a valid
        value.  Otherwise, returns the default value.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER InputObject
        The object to check the value of the requested property.

    .PARAMETER Name
        The name of the property on InputObject whose value is desired.

    .PARAMETER Type
        The type of the value stored in the Name property on InputObject.  Used to validate
        that the property has a valid value.

    .PARAMETER DefaultValue
        The value to return if Name doesn't exist on InputObject or is of an invalid type.

    .EXAMPLE
        Resolve-PropertyValue -InputObject $config -Name defaultOwnerName -Type String -DefaultValue $null

        Checks $config to see if it has a property named "defaultOwnerName".  If it does, and it's a
        string, returns that value, otherwise, returns $null (the DefaultValue).
#>
    [CmdletBinding()]
    param(
        [PSCustomObject] $InputObject,

        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [ValidateSet('String', 'Boolean', 'Int32', 'Int64')]
        [String] $Type,

        $DefaultValue
    )

    if ($null -eq $InputObject) {
        return $DefaultValue
    }

    $typeType = [String]
    if ($Type -eq 'Boolean') { $typeType = [Boolean] }
    if ($Type -eq 'Int32') { $typeType = [Int32] }
    if ($Type -eq 'Int64') { $typeType = [Int64] }
    $numberEquivalents = @('Int32', 'Int64', 'long', 'int')

    if (Test-PropertyExists -InputObject $InputObject -Name $Name) {
        if (($InputObject.$Name -is $typeType) -or
            (($Type -in $numberEquivalents) -and ($InputObject.$Name.GetType().Name -in $numberEquivalents))) {
            return $InputObject.$Name
        } else {
            return $DefaultValue
        }
    } else {
        return $DefaultValue
    }
}