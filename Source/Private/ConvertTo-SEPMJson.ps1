function Get-PSVersionMajor {
    <#
    .SYNOPSIS
        Returns the current PowerShell major version.
        Extracted for testability — tests mock this to exercise PS 5.1 code paths
        on PS 7+ hosts (where $PSVersionTable is Constant/AllScope and unwritable).
    #>
    return $PSVersionTable.PSVersion.Major
}

function ConvertTo-SEPMJson {
    <#
    .SYNOPSIS
        Safe JSON serializer at arbitrary depth on both PS 5.1 and PS 7+.

    .DESCRIPTION
        PS 7+: delegates to ConvertTo-Json -Depth $Depth with optional -Compress.
        PS 5.1: uses a recursive StringBuilder JSON serializer to avoid the
        built-in ConvertTo-Json depth 2 truncation.

        When using ConvertTo-JsonSafe (PS 5.1 path), float values are serialized
        via .ToString(). Values like NaN, Infinity, or -Infinity would produce
        invalid JSON — no current SEPM request body contains float fields.

    .PARAMETER InputObject
        The object to serialize.

    .PARAMETER Depth
        Maximum serialization depth. Default: 100.

    .PARAMETER Compress
        If set, produces compact JSON (no whitespace). Default: pretty-printed.

    .PARAMETER AsArray
        If set, wraps the output in a JSON array [ ... ].
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$InputObject,

        [int]$Depth = 100,

        [switch]$Compress,

        [switch]$AsArray
    )

    if ((Get-PSVersionMajor) -ge 6) {
        $json = $InputObject | ConvertTo-Json -Depth $Depth -Compress
    } else {
        $json = _ConvertTo-JsonSafe -obj $InputObject
    }

    if ($AsArray) {
        $json = "[$json]"
    }

    return $json
}

function _ConvertTo-JsonSafe {
    <#
    .SYNOPSIS
        Recursive JSON serializer using StringBuilder. Avoids PS 5.1
        ConvertTo-Json depth-2 truncation and JavaScriptSerializer PSObject wrapping bugs.

    .NOTES
        Float values use .ToString(). NaN, Infinity, or -Infinity produce
        invalid JSON — no current SEPM request body contains float fields.
    #>
    param($obj)
    $sb = New-Object System.Text.StringBuilder
    function _serialize {
        param($o, $sb)
        if ($null -eq $o) { [void]$sb.Append('null'); return }
        if ($o -is [string]) {
            [void]$sb.Append('"')
            [void]$sb.Append($o.Replace('\', '\\').Replace('"', '\"').Replace("`n", '\n').Replace("`r", '\r').Replace("`t", '\t'))
            [void]$sb.Append('"')
            return
        }
        if ($o -is [bool]) { [void]$sb.Append($o.ToString().ToLowerInvariant()); return }
        if ($o -is [int] -or $o -is [long] -or $o -is [double] -or $o -is [decimal]) { [void]$sb.Append($o); return }
        # Unwrap PSObject (except PSCustomObject)
        if ($o -is [PSObject] -and $o -isnot [PSCustomObject]) {
            $baseObj = $o.PSObject.BaseObject
            _serialize $baseObj $sb
            return
        }
        if ($o -is [System.Collections.IList]) {
            [void]$sb.Append('[')
            $first = $true
            foreach ($item in $o) {
                if (-not $first) { [void]$sb.Append(',') }
                _serialize $item $sb
                $first = $false
            }
            [void]$sb.Append(']')
            return
        }
        if ($o -is [System.Collections.IDictionary]) {
            [void]$sb.Append('{')
            $first = $true
            foreach ($key in $o.Keys) {
                if (-not $first) { [void]$sb.Append(',') }
                _serialize ([string]$key) $sb
                [void]$sb.Append(':')
                _serialize $o[$key] $sb
                $first = $false
            }
            [void]$sb.Append('}')
            return
        }
        if ($o -is [PSCustomObject]) {
            [void]$sb.Append('{')
            $first = $true
            foreach ($prop in $o.PSObject.Properties) {
                if ($prop.MemberType -eq 'NoteProperty') {
                    if (-not $first) { [void]$sb.Append(',') }
                    _serialize ([string]$prop.Name) $sb
                    [void]$sb.Append(':')
                    _serialize $prop.Value $sb
                    $first = $false
                }
            }
            [void]$sb.Append('}')
            return
        }
        # Fallback: ToString (floats end up here — see .NOTES)
        _serialize ([string]$o.ToString()) $sb
    }
    _serialize $obj $sb
    return $sb.ToString()
}
