function Resolve-SepmEndpoint {
    <#
    .SYNOPSIS
        Resolves a registry endpoint entry into a full URI.

    .DESCRIPTION
        Given an endpoint definition from the registry (Version, Path) and a session
        context (BaseURLv1, BaseURLv2), constructs the full API URI. Selects the API
        version prefix based on the endpoint's Version field.

    .PARAMETER Endpoint
        A hashtable from the endpoint registry with at least Version and Path keys.

    .PARAMETER Session
        A session object from Initialize-SEPMSession, providing BaseURLv1/BaseURLv2.

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
        [PSCustomObject]$Session
    )

    $baseUrl = if ($Endpoint.Version -eq '1.0') {
        $Session.BaseURLv1
    } else {
        $Session.BaseURLv2
    }

    return $baseUrl + $Endpoint.Path
}
