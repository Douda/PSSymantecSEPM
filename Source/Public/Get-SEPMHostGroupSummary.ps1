function Get-SEPMHostGroupSummary {
    <#
    .SYNOPSIS
        Gets a list of Host Group policy objects
    .DESCRIPTION
        Gets a paginated list of all Host Group policy objects from the SEPM API.
        Each object contains id, name, domainid, and lastmodifiedtime.
    .EXAMPLE
        PS C:\> Get-SEPMHostGroupSummary | Select-Object -First 1

        Gets the first host group summary
    .EXAMPLE
        PS C:\> Get-SEPMHostGroupSummary -DomainId 'abc123'

        Gets host group summaries scoped to a specific domain
#>

    [CmdletBinding()]
    param(
        [string]$DomainId
    )

    begin {
        $session = Initialize-SEPMSession
        $endpoint = Get-SEPMApiEndpoint -OperationName 'Get-SEPMHostGroupSummary'
    }

    process {
        $pageParams = @{
            pageSize  = 50
            pageIndex = 1
        }

        $allResults = @()
        do {
            $resp = Invoke-SepmEndpoint -Endpoint $endpoint -Session $session -BoundParameters $PSBoundParameters -AdditionalQueryParams $pageParams

            $allResults += $resp.content

            $pageParams.pageIndex++
        } until ($resp.lastPage -eq $true)

        Write-Output $allResults -NoEnumerate
    }
}
