function Optimize-ExceptionPolicyStructure {
    <#
    .SYNOPSIS
        This function is used to optimize the structure of the exception policy object.
    .DESCRIPTION
        This function is used to optimize the structure of the exception policy object.
        It will remove empty properties and nested objects that are empty.
    .PARAMETER obj
        The object to optimize
        
    .EXAMPLE
        Optimize-ExceptionPolicyStructure -obj $exceptionPolicy
    .OUTPUTS
        System.Management.Automation.PSCustomObject

    #>
    
    

    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true, 
            ValueFromPipeline = $true
        )]
        [object]
        $obj
    )

    process {
        # convert the object to a PSCustomObject (trick to convert custom class to PSCustomObject)
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            $obj = $obj | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100
        } else {
            # PS 5.1: ConvertTo-Json truncates at depth 2. Recursively clone
            # the PSObject tree to avoid depth-truncation corruption.
            function Clone-PSObjectTree($node) {
                if ($null -eq $node) { return $null }
                if ($node -is [string] -or $node -is [bool] -or $node -is [int] -or $node -is [long] -or $node -is [double]) {
                    return $node
                }
                if ($node -is [System.Collections.IList] -and $node -isnot [string]) {
                    $arr = @()
                    foreach ($item in $node) { $arr += Clone-PSObjectTree $item }
                    return $arr
                }
                if ($node -is [System.Collections.IDictionary]) {
                    $o = New-Object PSObject
                    foreach ($key in $node.Keys) { $o | Add-Member -NotePropertyName $key -NotePropertyValue (Clone-PSObjectTree $node[$key]) -Force }
                    return $o
                }
                # PSObject / PSCustomObject / class instance: clone safe property types.
                # Skip ScriptProperty, ParameterizedProperty, CodeProperty, Method to avoid
                # circular references during later JSON serialization.
                $safeTypes = @('NoteProperty', 'Property')
                $o = New-Object PSObject
                foreach ($prop in $node.PSObject.Properties) {
                    if ($prop.MemberType -in $safeTypes) {
                        $o | Add-Member -NotePropertyName $prop.Name -NotePropertyValue (Clone-PSObjectTree $prop.Value) -Force
                    }
                }
                return $o
            }
            $obj = Clone-PSObjectTree $obj
        }

        # Listing all properties of the object
        $AllProperties = $obj | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
        foreach ($property in $AllProperties) {
            # Conditional nested objects lookup
            switch ($property) {
                "configuration" {
                    # recursively call the function to dig deeper
                    $obj.$property = Optimize-ExceptionPolicyStructure $obj.$property
                    
                    # If configuration object is empty, remove it
                    if (($obj.$property | Get-Member -MemberType NoteProperty).count -eq 0) {
                        $obj = $obj | Select-Object -ExcludeProperty $property
                    }
                }
                "lockedoptions" {
                    # TODO Change the lockedoptions cleanup way via a custom method in the class
                    # # list all properties of the lockedoptions object
                    # $lockedproperties = $obj.$property | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
                    
                    # # Parse the lockedoptions properties and remove the ones with $null values
                    # foreach ($lockedproperty in $lockedproperties) {
                    #     if ($null -eq $obj.$property.$lockedproperty) {
                    #         $obj.$property = $obj.$property | Select-Object -ExcludeProperty $lockedproperty
                    #     }
                    # }

                    # If lockedoptions object is empty, remove it
                    if (($obj.$property | Get-Member -MemberType NoteProperty).count -eq 0) {
                        $obj = $obj | Select-Object -ExcludeProperty $property
                    }
                }
                "extension_list" {
                    # If no extensions are defined, remove the extension_list property
                    if ($obj.$property.extensions.count -eq 0) {
                        $obj = $obj | Select-Object -ExcludeProperty $property
                    }
                }
                "mac" {
                    # If no files are defined, remove the mac property
                    if ($obj.$property.files.count -eq 0) {
                        $obj = $obj | Select-Object -ExcludeProperty $property
                    }
                }
                "linux" {
                    # If no directories are defined, remove the directories list
                    if ($obj.$property.directories.count -eq 0) {
                        $obj.$property = $obj.$property | Select-Object -ExcludeProperty "directories"
                    }

                    # If no extensions are defined, remove them from the linux object
                    if ($obj.$property.extension_list.extensions.count -eq 0) {
                        $obj.$property = $obj.$property | Select-Object -ExcludeProperty "extension_list"
                    }

                    # If linux object is empty, remove it
                    if (($obj.$property | Get-Member -MemberType NoteProperty).count -eq 0) {
                        $obj = $obj | Select-Object -ExcludeProperty $property
                    }
                }
            }

            # If the property is empty, remove the property
            if ($obj.$property.count -eq 0) {
                $obj = $obj | Select-Object -ExcludeProperty $property
            }

            # If the property is null, remove the property
            if ($null -eq $obj.$property) {
                $obj = $obj | Select-Object -ExcludeProperty $property
            }
        }
        return $obj
    }
    
}