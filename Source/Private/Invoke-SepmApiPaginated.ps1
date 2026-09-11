function Invoke-SepmApiPaginated {
    <#
    .SYNOPSIS
        Calls a paginated SEPM API endpoint, concatenating all pages.

    .DESCRIPTION
        Starts pageIndex = 1, merges $Endpoint.PageDefaults into query params,
        calls Resolve-SepmEndpoint + Invoke-SepmApi per page, and concatenates
        $resp.content arrays. Returns the full result array via Write-Output
        -NoEnumerate.

        A failed page is retried once after a short pause, then the whole read is
        aborted with a Transport Error naming the page, so a caller never silently
        receives a partial result. The retry lives here rather than in Invoke-SepmApi
        because only these reads are GETs: retrying in the transport would also retry
        POSTs, where a slow-but-successful create would be applied twice.

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

        # Retry the page once before giving up. Only GETs reach this loop, so re-issuing
        # the request is safe; the pause is what gives a transient blip a chance to clear,
        # since an immediate retry tends to hit the same failure again.
        $attempt = 0
        do {
            try {
                $resp = Invoke-SepmApi @apiSplat
                break
            } catch {
                $attempt++
                $currentPage = $queryParams['pageIndex']
                if ($attempt -ge 2) {
                    # Keep the original ErrorId and Category, and add the page context the
                    # transport could not know.
                    if ($currentPage -le 1) {
                        $context = 'the first page failed'
                    } else {
                        $context = "page $currentPage failed; pages 1-$($currentPage - 1) were read successfully"
                    }
                    $PSCmdlet.ThrowTerminatingError((New-SEPMApiError `
                                -Message "$($_.Exception.Message) ($context)" `
                                -ErrorId $_.FullyQualifiedErrorId.Split(',')[0] `
                                -Category $_.CategoryInfo.Category `
                                -Target $_.TargetObject))
                }
                Write-Verbose "Page $currentPage of $($Endpoint.OperationName) failed, retrying once: $($_.Exception.Message)"
                Start-Sleep -Milliseconds 1000
            }
        } while ($true)

        # The response must carry lastPage - it is the loop's only termination condition. A
        # string payload (a non-JSON body returned with a 2xx status) has no properties at all,
        # so trusting it would spin this loop forever against the server. The transport only
        # rejects a string when the HTTP status is an error, so it is checked here too.
        if ($null -eq $resp -or $resp -is [string] -or $null -eq $resp.lastPage) {
            $PSCmdlet.ThrowTerminatingError((New-SEPMApiError `
                        -Message "SEPM API $($Endpoint.Method) $($Endpoint.Path) returned a response with no 'lastPage' field, so pagination cannot continue (page $($queryParams['pageIndex']))." `
                        -Category ([System.Management.Automation.ErrorCategory]::InvalidResult) `
                        -Target $uri))
        }

        if ($resp.content) {
            $allResults += $resp.content
        }

        $currentPage = $queryParams['pageIndex']
        if ($resp.totalPages -and $resp.totalPages -gt 1) {
            $percent = [math]::Floor(($currentPage / $resp.totalPages) * 100)
            Write-Progress -Activity $Endpoint.OperationName -Status "Page $currentPage of $($resp.totalPages)" -PercentComplete $percent
        } elseif ($currentPage -gt 1) {
            Write-Progress -Activity $Endpoint.OperationName -Status "Page $currentPage" -PercentComplete -1
        }

        $queryParams['pageIndex']++

    } until ($resp.lastPage -eq $true)

    Write-Progress -Activity $Endpoint.OperationName -Completed

    Write-Output $allResults -NoEnumerate
}
