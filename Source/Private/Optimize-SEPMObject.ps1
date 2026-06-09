function Optimize-SEPMObject {
    <#
    .SYNOPSIS
        Clones an object to a clean PSCustomObject tree and strips null/empty
        properties according to SEPM domain rules.
    .DESCRIPTION
        Accepts any object via pipeline, clones it to a clean PSCustomObject
        tree (removing class wrappers), then strips null properties, empty
        arrays, empty IDictionary instances, and applies SEPM-specific
        empty-property rules (mac, linux, extension_list, lockedoptions).
    .PARAMETER InputObject
        The object to clone and optimize.
    .EXAMPLE
        $clean = Optimize-SEPMObject -InputObject $exceptionPolicy
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
        $InputObject
    )

    begin {
        # Recursively clone a PSObject tree (PS 5.1 path when ConvertTo-Json depth is unreliable).
        # Skip ScriptProperty, ParameterizedProperty, CodeProperty, Method to avoid circular
        # references during later JSON serialization.
        function Clone-PSObjectTree {
            param([object]$node)

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
                foreach ($key in $node.Keys) {
                    $o | Add-Member -NotePropertyName $key -NotePropertyValue (Clone-PSObjectTree $node[$key]) -Force
                }
                return $o
            }

            $safeTypes = @('NoteProperty', 'Property')
            $o = New-Object PSObject
            foreach ($prop in $node.PSObject.Properties) {
                if ($prop.MemberType -in $safeTypes) {
                    $o | Add-Member -NotePropertyName $prop.Name -NotePropertyValue (Clone-PSObjectTree $prop.Value) -Force
                }
            }
            return $o
        }
    }

    process {
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            $obj = $InputObject | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100
        } else {
            $obj = Clone-PSObjectTree $InputObject
        }

        $allProperties = $obj | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
        foreach ($property in $allProperties) {
            $val = $obj.$property
            $strip = $false

            if ($null -eq $val) {
                $strip = $true
            } elseif ($val -is [System.Collections.IList] -and $val.Count -eq 0) {
                $strip = $true
            } elseif ($val -is [System.Collections.IDictionary] -and $val.Count -eq 0) {
                $strip = $true
            } elseif ($val -is [PSCustomObject] -and ($val | Get-Member -MemberType NoteProperty).Count -eq 0) {
                $strip = $true
            }

            # SEPM domain rules — strip properties whose sub-structure is empty
            # even though the wrapper object itself has properties.
            if (-not $strip) {
                switch ($property) {
                    'mac' {
                        if ($val.files.Count -eq 0) { $strip = $true }
                    }
                    'linux' {
                        $hasDirs = ($null -ne $val.directories) -and ($val.directories.Count -gt 0)
                        $hasExts = ($null -ne $val.extension_list) -and
                                   ($null -ne $val.extension_list.extensions) -and
                                   ($val.extension_list.extensions.Count -gt 0)
                        if (-not $hasDirs -and -not $hasExts) { $strip = $true }
                    }
                    'extension_list' {
                        if ($val.extensions.Count -eq 0) { $strip = $true }
                    }
                }
            }

            if ($strip) {
                $obj = $obj | Select-Object -ExcludeProperty $property
            }
        }

        return $obj
    }
}
