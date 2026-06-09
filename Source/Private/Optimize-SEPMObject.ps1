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

    process {
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            $obj = $InputObject | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100
        } else {
            # PS 5.1: ConvertTo-Json truncates at depth 2. Recursively clone
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
                $safeTypes = @('NoteProperty', 'Property')
                $o = New-Object PSObject
                foreach ($prop in $node.PSObject.Properties) {
                    if ($prop.MemberType -in $safeTypes) {
                        $o | Add-Member -NotePropertyName $prop.Name -NotePropertyValue (Clone-PSObjectTree $prop.Value) -Force
                    }
                }
                return $o
            }
            $obj = Clone-PSObjectTree $InputObject
        }

        # Strip null and empty properties + SEPM domain rules
        $allProperties = $obj | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
        foreach ($property in $allProperties) {
            $val = $obj.$property
            $strip = $false
            if ($null -eq $val) { $strip = $true }
            elseif ($val -is [System.Collections.IList] -and $val.Count -eq 0) { $strip = $true }
            elseif ($val -is [System.Collections.IDictionary] -and $val.Count -eq 0) { $strip = $true }
            elseif ($val -is [PSCustomObject] -and ($val | Get-Member -MemberType NoteProperty).Count -eq 0) { $strip = $true }

            # SEPM domain rules
            if ($property -eq 'mac' -and -not $strip) {
                if ($val.files.Count -eq 0) { $strip = $true }
            }
            if ($property -eq 'linux' -and -not $strip) {
                $dirsEmpty = $true
                if ($val.directories) { $dirsEmpty = ($val.directories.Count -eq 0) }
                $extsEmpty = $true
                if ($val.extension_list -and $val.extension_list.extensions) {
                    if ($val.extension_list.extensions.Count -gt 0) { $extsEmpty = $false }
                }
                if ($dirsEmpty -and $extsEmpty) { $strip = $true }
            }
            if ($property -eq 'extension_list' -and -not $strip) {
                if ($val.extensions.Count -eq 0) { $strip = $true }
            }
            if ($property -eq 'lockedoptions' -and -not $strip) {
                if (($val | Get-Member -MemberType NoteProperty).Count -eq 0) { $strip = $true }
            }

            if ($strip) {
                $obj = $obj | Select-Object -ExcludeProperty $property
            }
        }

        return $obj
    }
}
