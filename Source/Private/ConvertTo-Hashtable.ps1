function ConvertTo-Hashtable {
    <#
    .SYNOPSIS
        Recursively converts a PSCustomObject, OrderedDictionary, IDictionary,
        or array to a plain [hashtable]. Used to unify response types across
        PS 7+ (Invoke-RestMethod → PSCustomObject) and PS 5.1
        (JavaScriptSerializer → IDictionary).

    .DESCRIPTION
        PS 7 Invoke-RestMethod returns PSCustomObject for JSON objects.
        PS 5.1 JavaScriptSerializer returns Dictionary<string,object>.
        This function normalizes both to [hashtable] so callers do not
        need PS-version-dependent response handling.

    .PARAMETER InputObject
        The object to convert. Supports PSCustomObject, IDictionary,
        OrderedDictionary, IList (arrays), and scalars (returned as-is).

    .EXAMPLE
        $ht = ConvertTo-Hashtable -InputObject [PSCustomObject]@{ a = 1; b = 2 }
        # Returns a [hashtable] with keys 'a' and 'b'

    .NOTES
        Internal helper. Not exported.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [AllowNull()]
        $InputObject
    )

    process {
        if ($null -eq $InputObject) { return $null }

        # Already a hashtable → return as-is
        if ($InputObject -is [hashtable]) { return $InputObject }

        # IDictionary (including OrderedDictionary, generic Dictionary) → convert
        if ($InputObject -is [System.Collections.IDictionary]) {
            $ht = @{}
            foreach ($key in $InputObject.Keys) {
                $ht[$key] = ConvertTo-Hashtable -InputObject $InputObject[$key]
            }
            return $ht
        }

        # PSCustomObject → convert via PSObject.Properties
        if ($InputObject -is [PSCustomObject]) {
            $ht = @{}
            foreach ($prop in $InputObject.PSObject.Properties) {
                $ht[$prop.Name] = ConvertTo-Hashtable -InputObject $prop.Value
            }
            return $ht
        }

        # Array / IList (but not string) → convert each element
        if ($InputObject -is [System.Collections.IList] -and $InputObject -isnot [string]) {
            $arr = [System.Collections.Generic.List[object]]::new()
            foreach ($item in $InputObject) {
                $arr.Add((ConvertTo-Hashtable -InputObject $item))
            }
            Write-Output $arr.ToArray() -NoEnumerate
            return
        }

        # Scalar → return as-is
        return $InputObject
    }
}
