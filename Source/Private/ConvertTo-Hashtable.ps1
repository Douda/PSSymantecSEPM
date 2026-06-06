function ConvertTo-Hashtable {
    <#
    .SYNOPSIS
        Recursively converts PSCustomObject to [ordered] hashtable.
        Used on PS 5.1 to match PS7 ConvertFrom-Json -AsHashtable behavior
        for functions that use indexer syntax ($obj["key"]).
    #>
    param($obj)

    if ($null -eq $obj) { return $null }

    if ($obj -is [System.Collections.IList] -and $obj -isnot [string]) {
        $arr = @()
        foreach ($item in $obj) {
            $arr += ConvertTo-Hashtable $item
        }
        return $arr
    }

    if ($obj -is [PSCustomObject] -or $obj -is [System.Management.Automation.PSObject]) {
        $ht = [ordered]@{}
        foreach ($prop in $obj.PSObject.Properties) {
            if ($prop.MemberType -eq 'NoteProperty') {
                $ht[$prop.Name] = ConvertTo-Hashtable $prop.Value
            }
        }
        return $ht
    }

    if ($obj -is [System.Collections.IDictionary]) {
        $ht = [ordered]@{}
        foreach ($key in $obj.Keys) {
            $ht[$key] = ConvertTo-Hashtable $obj[$key]
        }
        return $ht
    }

    return $obj
}
