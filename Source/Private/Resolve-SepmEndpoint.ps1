function Resolve-SepmEndpoint {
    <#
    .SYNOPSIS
        Resolves a registry endpoint entry into a full URI, including query parameters.

    .DESCRIPTION
        Given an endpoint definition from the registry (Version, Path, optional QueryParams)
        and a session context (BaseURLv1, BaseURLv2), constructs the full API URI.
        Selects the API version prefix based on the endpoint's Version field.

        QueryParams resolution: for each API query key in the registry entry, attempts to
        resolve its value from BoundParameters using the explicit mapping (e.g.,
        domainId = Domain). If no mapping exists and a parameter with the same name as the
        API key is bound, it is used as a same-name fallback. AdditionalQueryParams from
        the caller are merged in (module-scoped values, hardcoded defaults).

    .PARAMETER Endpoint
        A hashtable from the endpoint registry with at least Version and Path keys.

    .PARAMETER Session
        A session object from Initialize-SEPMSession, providing BaseURLv1/BaseURLv2.

    .PARAMETER BoundParameters
        The cmdlet's $PSBoundParameters hashtable for resolving query param values.

    .PARAMETER AdditionalQueryParams
        Extra query params to append (module-scoped values, hardcoded defaults).

    .OUTPUTS
        System.String. The full URI for the API call.

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

        [hashtable]$AdditionalQueryParams
    )

    $baseUrl = if ($Endpoint.Version -eq '1.0') {
        $Session.BaseURLv1
    } else {
        $Session.BaseURLv2
    }

    $uri = $baseUrl + $Endpoint.Path

    # Resolve query params from registry mapping + caller extras
    $queryParams = @{}

    if ($Endpoint.QueryParams -and $BoundParameters) {
        foreach ($apiKey in $Endpoint.QueryParams.Keys) {
            $paramName = $Endpoint.QueryParams[$apiKey]
            if ($BoundParameters.ContainsKey($paramName)) {
                $queryParams[$apiKey] = $BoundParameters[$paramName]
            } elseif ($BoundParameters.ContainsKey($apiKey)) {
                $queryParams[$apiKey] = $BoundParameters[$apiKey]
            }
        }
    }

    # Merge caller-provided additional query params (module-scoped values, hardcoded defaults)
    if ($AdditionalQueryParams) {
        foreach ($key in $AdditionalQueryParams.Keys) {
            $queryParams[$key] = $AdditionalQueryParams[$key]
        }
    }

    # Build query string
    if ($queryParams.Count -gt 0) {
        $builder = New-Object System.UriBuilder($uri)
        $query = [System.Web.HttpUtility]::ParseQueryString($builder.Query)
        foreach ($key in $queryParams.Keys) {
            $query[$key] = $queryParams[$key]
        }
        $builder.Query = $query.ToString()
        $uri = $builder.ToString()
    }

    return $uri
}
