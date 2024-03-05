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
        # There might be cleaner ways to do this
        $obj = $obj | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100

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