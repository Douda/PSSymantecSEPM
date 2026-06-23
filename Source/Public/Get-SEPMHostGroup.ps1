function Get-SEPMHostGroup {
    <#
    .SYNOPSIS
        Gets a Host Group policy object by ID or name
    .DESCRIPTION
        Gets full Host Group detail (including the hosts[] array of network entities)
        by ID or by name. When using -Name, the cmdlet internally resolves the name
        against the summary endpoint and returns matching Host Groups in full detail.
        Supports wildcards in -Name for bulk retrieval.
    .EXAMPLE
        PS C:\> Get-SEPMHostGroup -Id 'abc123'

        Gets the full Host Group object for the given ID
    .EXAMPLE
        PS C:\> $obj | Get-SEPMHostGroup

        Gets the full Host Group object via pipeline (id property)
    .EXAMPLE
        PS C:\> Get-SEPMHostGroup -Name 'WebServers'

        Resolves the Host Group by name and returns full detail
    .EXAMPLE
        PS C:\> Get-SEPMHostGroup -Name 'DMZ-*'

        Returns ALL Host Groups whose name matches the wildcard
#>

    [CmdletBinding(DefaultParameterSetName = 'ById')]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'ById'
        )]
        [string]$Id,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = 'ByName'
        )]
        [SupportsWildcards()]
        [string]$Name
    )

    begin {
        $session = Initialize-SEPMSession
        $detailEndpoint = Get-SEPMApiEndpoint -OperationName 'Get-SEPMHostGroup'

        if ($PSCmdlet.ParameterSetName -eq 'ByName') {
            $summaryEndpoint = Get-SEPMApiEndpoint -OperationName 'Get-SEPMHostGroupSummary'
        }
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'ById') {
            $resp = Invoke-SepmEndpoint -Endpoint $detailEndpoint -Session $session -PathIds @($Id)
            Write-Output $resp
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'ByName') {
            # Step 1: Paginate through summary endpoint
            $pageParams = @{
                pageSize  = 50
                pageIndex = 1
            }
            $summaryResults = @()
            do {
                $resp = Invoke-SepmEndpoint -Endpoint $summaryEndpoint -Session $session -AdditionalQueryParams $pageParams
                $summaryResults += $resp.content
                $pageParams.pageIndex++
            } until ($resp.lastPage -eq $true)

            # Step 2: Filter by name (supports wildcards)
            $nameMatches = $summaryResults | Where-Object { $_.name -like $Name }

            # Step 3: No matches
            if (-not $nameMatches -or $nameMatches.Count -eq 0) {
                return @()
            }

            # Step 4: Fetch full detail for each match
            $results = @()
            foreach ($match in $nameMatches) {
                $detail = Invoke-SepmEndpoint -Endpoint $detailEndpoint -Session $session -PathIds @($match.id)
                $results += $detail
            }

            # Step 5: Return array (single or multiple)
            Write-Output $results -NoEnumerate
        }
    }
}
