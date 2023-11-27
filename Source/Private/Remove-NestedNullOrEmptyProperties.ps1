function Remove-NestedNullOrEmptyProperties {
    <#
    .SYNOPSIS
        Remove nested properties with $null or empty values from a PSObject
    .DESCRIPTION
        This function will recursively iterate over all properties of a PSObject or list of PSObjects and remove the ones with $null or empty values.
    .EXAMPLE
        $obj = [PSCustomObject]@{
            "property1" = "value1"
            "property2" = $null
            "property3" = ""
            "property4" = [PSCustomObject]@{
                "property5" = "value5"
                "property6" = $null
                "property7" = ""
                "property8" = [PSCustomObject]@{
                    "property9" = "value9"
                    "property10" = $null
                    "property11" = ""
                }
            }
        }
        $obj = Remove-NestedNullOrEmptyProperties -InputObject $obj
        $obj | ConvertTo-Json
        {
        "property1": "value1",
        "property4": {
                        "property5": "value5",
                        "property8": {
                                            "property9": "value9"
                                        }
                }
    }
    .NOTES
        helper function
    #>

    
    param (
        [Parameter(Mandatory = $true)]
        [PSObject] $InputObject
    )

    # Get all properties of the input object
    $properties = $InputObject | Get-Member -MemberType NoteProperty -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name

    # Iterate over the properties and remove the ones with $null values
    foreach ($property in $properties) {
        # If the property value is $null, remove the property
        if ($null -eq $InputObject.$property) {
            $InputObject = $InputObject | Select-Object -ExcludeProperty $property
        }
        # If the property value is an empty string, remove the property
        elseif ($InputObject.$property -eq "") {
            $InputObject = $InputObject | Select-Object -ExcludeProperty $property
        }
        # If the property value is another PSObject, recursively call this function
        elseif ($InputObject.$property -is [PSObject]) {
            $InputObject.$property = Remove-NestedNullOrEmptyProperties -InputObject $InputObject.$property -ErrorAction SilentlyContinue
        }
        # If the property value is a list of PSObjects, iterate over the list and recursively call this function on each item
        elseif ($InputObject.$property -is [System.Collections.IEnumerable] -and 
            $InputObject.$property -isnot [string]) {
            $InputObject.$property = $InputObject.$property | ForEach-Object {
                if ($_ -is [PSObject]) {
                    Remove-NestedNullOrEmptyProperties -InputObject $_
                } else {
                    $_
                }
            }
        }
    }

    # Return the modified object
    return $InputObject
}