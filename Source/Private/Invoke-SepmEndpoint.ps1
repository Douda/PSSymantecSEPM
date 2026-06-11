function Invoke-SepmEndpoint {
    <#
    .SYNOPSIS
        Resolves an endpoint and dispatches it through Invoke-SepmApi.

    .DESCRIPTION
        Takes an endpoint definition from the registry and a session, resolves the full
        URI via Resolve-SepmEndpoint, and calls Invoke-SepmApi with the correct Method,
        Uri, and Session. This is the single entry point all public cmdlets use to reach
        the transport layer.

        When the endpoint declares BodyParams, builds a flat hashtable body from
        $BoundParameters using the explicit mapping (API key name = param name).
        Switch parameters are converted to boolean. Null/empty string values are omitted.
        The body is serialized to JSON and sent with ContentType 'application/json'.

        A pre-serialized -Body argument takes precedence over BodyParams auto-build
        (for cmdlets with complex nested bodies).

    .PARAMETER Endpoint
        A hashtable from the endpoint registry with at least Method, Version, and Path.

    .PARAMETER Session
        A session object from Initialize-SEPMSession.

    .PARAMETER BoundParameters
        The cmdlet's $PSBoundParameters hashtable for resolving query param values
        and/or BodyParams values.

    .PARAMETER AdditionalQueryParams
        Extra query params to append (module-scoped values, hardcoded defaults).

    .PARAMETER PathIds
        An array of ID values for {id} placeholder substitution in the path template.
        Passed through to Resolve-SepmEndpoint.

    .PARAMETER Body
        Pre-serialized JSON body string. When provided, overrides BodyParams auto-build.
        Use for complex bodies the flat auto-build cannot express.

    .OUTPUTS
        System.Collections.Hashtable. The API response.

    .NOTES
        Internal helper method. Not exported.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Endpoint,

        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Session,

        [hashtable]$BoundParameters,

        [hashtable]$AdditionalQueryParams,

        [string[]]$PathIds,

        [string]$Body
    )

    $uri = Resolve-SepmEndpoint -Endpoint $Endpoint -Session $Session -BoundParameters $BoundParameters -AdditionalQueryParams $AdditionalQueryParams -PathIds $PathIds

    # Build body: explicit -Body override takes precedence, then BodyParams auto-build
    $bodyToSend = $Body
    if (-not $bodyToSend -and $Endpoint.BodyParams -and $BoundParameters) {
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
            $bodyToSend = ConvertTo-SEPMJson -InputObject $builtBody
        }
    }

    # Build splat for Invoke-SepmApi
    $apiSplat = @{
        Method  = $Endpoint.Method
        Uri     = $uri
        Session = $Session
    }
    if ($bodyToSend) {
        $apiSplat.Body = $bodyToSend
        $apiSplat.ContentType = 'application/json'
    }

    return Invoke-SepmApi @apiSplat
}
