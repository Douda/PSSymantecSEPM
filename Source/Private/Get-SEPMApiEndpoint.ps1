# The declarative endpoint registry maps each exported cmdlet name to its
# API contract (version, HTTP method, path). Initialized once at module
# import. See docs/adr/0008-endpoint-registry.md.
if (-not $script:_endpointRegistry) {
    $script:_endpointRegistry = @{
        'Get-SEPMVersion' = @{
            OperationName = 'Get-SEPMVersion'
            Version       = '1.0'
            Method        = 'GET'
            Path          = '/version'
        }
    }
}

function Get-SEPMApiEndpoint {
    <#
    .SYNOPSIS
        Returns the registry entry for a given SEPM API operation.

    .DESCRIPTION
        Looks up the declarative endpoint registry and returns the entry (Version, Method,
        Path, etc.) for the specified operation name. The registry defines every SEPM API
        call the module supports.

    .PARAMETER OperationName
        The name of the exported cmdlet (e.g. 'Get-SEPMVersion').

    .OUTPUTS
        System.Collections.Hashtable with keys: OperationName, Version, Method, Path.

    .NOTES
        Internal helper method. Not exported.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OperationName
    )

    if (-not $script:_endpointRegistry.ContainsKey($OperationName)) {
        throw "No endpoint registered for operation '$OperationName'."
    }

    return $script:_endpointRegistry[$OperationName]
}
