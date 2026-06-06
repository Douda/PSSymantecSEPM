function ConvertFrom-DictionaryToPSObject {
    <#
    .SYNOPSIS
        Recursively converts Dictionary/ArrayList from JavaScriptSerializer to PSCustomObject.
        Used on PS 5.1 to match Invoke-RestMethod's JSON parsing behavior.
    #>
    param($obj)

    if ($null -eq $obj) { return $null }

    if ($obj -is [System.Collections.IDictionary]) {
        $result = New-Object PSObject
        foreach ($key in $obj.Keys) {
            $val = ConvertFrom-DictionaryToPSObject $obj[$key]
            $result | Add-Member -MemberType NoteProperty -Name $key -Value $val -Force
        }
        return $result
    }

    if ($obj -is [System.Collections.IList] -and $obj -isnot [string]) {
        $arr = @()
        foreach ($item in $obj) {
            $arr += ConvertFrom-DictionaryToPSObject $item
        }
        return $arr
    }

    return $obj
}
