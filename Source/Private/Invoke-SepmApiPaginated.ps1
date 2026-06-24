function Invoke-SepmApiPaginated {
    <#
    .SYNOPSIS
        Calls a paginated SEPM API endpoint, concatenating all pages.

    .DESCRIPTION
        Starts pageIndex = 1, merges $Endpoint.PageDefaults into query params,
        calls Resolve-SepmEndpoint + Invoke-SepmApi per page, and concatenates
        $resp.content arrays. Returns the full result array via Write-Output
        -NoEnumerate. Throws immediately if Invoke-SepmApi returns a string
        (error response).

    .PARAMETER Endpoint
        A hashtable from the endpoint registry with Method, Version, Path,
        Paginated, PageDefaults, etc.

    .PARAMETER Session
        A session object from Initialize-SEPMSession.

    .PARAMETER BoundParameters
        The cmdlet's $PSBoundParameters hashtable for resolving query param
        values and/or BodyParams values.

    .PARAMETER AdditionalQueryParams
        Extra query params to append (module-scoped values, hardcoded defaults).

    .PARAMETER PathIds
        An array of ID values for {id} placeholder substitution.

    .PARAMETER Body
        Pre-serialized JSON body string. Passed through to Invoke-SepmApi
        for endpoints that need a request body.

    .OUTPUTS
        System.Object[] containing concatenated page content.

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

    if (-not $Endpoint.Paginated) {
        throw "Endpoint '$($Endpoint.OperationName)' is not configured for pagination."
    }

    # Merge PageDefaults and AdditionalQueryParams into query params
    $queryParams = @{}
    if ($Endpoint.PageDefaults) {
        foreach ($key in $Endpoint.PageDefaults.Keys) {
            $queryParams[$key] = $Endpoint.PageDefaults[$key]
        }
    }
    $queryParams['pageIndex'] = 1

    if ($AdditionalQueryParams) {
        foreach ($key in $AdditionalQueryParams.Keys) {
            $queryParams[$key] = $AdditionalQueryParams[$key]
        }
    }

    # Build body once — it does not change between pages
    $bodyToSend = Build-SepmBody -Endpoint $Endpoint -BoundParameters $BoundParameters -Body $Body

    $allResults = @()

    do {
        $uri = Resolve-SepmEndpoint -Endpoint $Endpoint -Session $Session -BoundParameters $BoundParameters -AdditionalQueryParams $queryParams -PathIds $PathIds

        $apiSplat = @{
            Method  = $Endpoint.Method
            Uri     = $uri
            Session = $Session
        }
        if ($bodyToSend) {
            $apiSplat.Body = $bodyToSend
            $apiSplat.ContentType = 'application/json'
        }

        $resp = Invoke-SepmApi @apiSplat

        # If Invoke-SepmApi returns a string, it's an error — throw immediately
        if ($resp -is [string]) {
            throw "Paginated API call failed: $resp"
        }

        if ($resp.content) {
            $allResults += $resp.content
        }

        # Emit Write-Progress for multi-page fetches
        $currentPage = $queryParams['pageIndex']
        if ($resp.totalPages -and $resp.totalPages -gt 1) {
            $percent = [math]::Floor(($currentPage / $resp.totalPages) * 100)
            Write-Progress -Activity $Endpoint.OperationName -Status "Page $currentPage of $($resp.totalPages)" -PercentComplete $percent
        } elseif ($currentPage -gt 1) {
            Write-Progress -Activity $Endpoint.OperationName -Status "Page $currentPage" -PercentComplete -1
        }

        $queryParams['pageIndex']++

    } until ($resp.lastPage -eq $true)

    # Clear the progress bar
    Write-Progress -Activity $Endpoint.OperationName -Completed

    Write-Output $allResults -NoEnumerate
}
