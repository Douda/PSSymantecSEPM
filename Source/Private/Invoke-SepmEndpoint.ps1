function Invoke-SepmEndpoint {
    <#
    .SYNOPSIS
        Resolves an endpoint and dispatches it through Invoke-SepmApi or Invoke-SepmApiPaginated.

    .DESCRIPTION
        Takes an endpoint definition from the registry and a session, resolves the full
        URI via Resolve-SepmEndpoint, and calls Invoke-SepmApi with the correct Method,
        Uri, and Session. This is the single entry point all public cmdlets use to reach
        the transport layer.

        When the endpoint declares BodyParams, delegates body construction to
        Build-SepmBody. A pre-serialized -Body argument takes precedence
        over BodyParams auto-build (for cmdlets with complex nested bodies).

        When the endpoint declares Paginated = $true, delegates to
        Invoke-SepmApiPaginated which handles page iteration and concatenation,
        returning the full array of items directly.

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
        System.Collections.Hashtable or System.Object[] (paginated endpoints).

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

    # Paginated endpoint: delegate to Invoke-SepmApiPaginated
    if ($Endpoint.Paginated) {
        return Invoke-SepmApiPaginated -Endpoint $Endpoint -Session $Session -BoundParameters $BoundParameters -AdditionalQueryParams $AdditionalQueryParams -PathIds $PathIds -Body $Body
    }

    $uri = Resolve-SepmEndpoint -Endpoint $Endpoint -Session $Session -BoundParameters $BoundParameters -AdditionalQueryParams $AdditionalQueryParams -PathIds $PathIds

    $bodyToSend = Build-SepmBody -Endpoint $Endpoint -BoundParameters $BoundParameters -Body $Body

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
