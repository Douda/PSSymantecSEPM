function Build-SepmBody {
    <#
    .SYNOPSIS
        Builds a JSON request body from endpoint BodyParams and BoundParameters.

    .DESCRIPTION
        Extracts body-building logic from Invoke-SepmEndpoint into a dedicated function.
        When -Body is provided, returns it as-is (pre-serialized body override).
        Otherwise, if the endpoint declares BodyParams, builds a flat hashtable from
        the mapping (skipping nulls and empty strings, converting switches to booleans),
        then serialises via ConvertTo-SEPMJson. Returns $null when neither path produces
        a body.

    .PARAMETER Endpoint
        A hashtable from the endpoint registry with an optional BodyParams key.

    .PARAMETER BoundParameters
        The cmdlet's $PSBoundParameters hashtable for resolving BodyParams values.

    .PARAMETER Body
        Pre-serialized JSON body string. When provided, overrides BodyParams auto-build.
        Use for complex bodies the flat auto-build cannot express.

    .OUTPUTS
        System.String or $null. JSON string if a body was built, $null otherwise.

    .NOTES
        Internal helper method. Not exported.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Endpoint,

        [hashtable]$BoundParameters,

        [string]$Body
    )

    # Pre-serialized body override takes precedence
    if ($Body) {
        return $Body
    }

    # Auto-build from BodyParams mapping
    if ($Endpoint.BodyParams -and $BoundParameters) {
        $builtBody = @{}
        foreach ($apiKey in $Endpoint.BodyParams.Keys) {
            $paramName = $Endpoint.BodyParams[$apiKey]
            if ($BoundParameters.ContainsKey($paramName)) {
                $value = $BoundParameters[$paramName]
                # Omit null/empty values
                if ($null -eq $value) { continue }
                if ($value -is [string] -and [string]::IsNullOrEmpty($value)) { continue }
                # Convert switch to boolean
                if ($value -is [switch]) { $value = $value.ToBool() }
                $builtBody[$apiKey] = $value
            }
        }
        if ($builtBody.Count -gt 0) {
            return ConvertTo-SEPMJson -InputObject $builtBody
        }
    }

    return $null
}
