function Invoke-SepmEndpoint {
    <#
    .SYNOPSIS
        Resolves an endpoint and dispatches it through Invoke-SepmApi.

    .DESCRIPTION
        Takes an endpoint definition from the registry and a session, resolves the full
        URI via Resolve-SepmEndpoint, and calls Invoke-SepmApi with the correct Method,
        Uri, and Session. This is the single entry point all public cmdlets use to reach
        the transport layer.

    .PARAMETER Endpoint
        A hashtable from the endpoint registry with at least Method, Version, and Path.

    .PARAMETER Session
        A session object from Initialize-SEPMSession.

    .PARAMETER BoundParameters
        The cmdlet's $PSBoundParameters hashtable for resolving query param values.

    .PARAMETER AdditionalQueryParams
        Extra query params to append (module-scoped values, hardcoded defaults).

    .PARAMETER PathIds
        An array of ID values for {id} placeholder substitution in the path template.
        Passed through to Resolve-SepmEndpoint.

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

        [string[]]$PathIds
    )

    $uri = Resolve-SepmEndpoint -Endpoint $Endpoint -Session $Session -BoundParameters $BoundParameters -AdditionalQueryParams $AdditionalQueryParams -PathIds $PathIds

    return Invoke-SepmApi -Method $Endpoint.Method -Uri $uri -Session $Session
}
