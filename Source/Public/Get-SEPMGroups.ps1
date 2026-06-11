function Get-SEPMGroups {
    <#
    .SYNOPSIS
        Gets a group list
    .DESCRIPTION
        Gets a group list
    .EXAMPLE
        PS C:\GitHub_Projects\PSSymantecSEPM> Get-SEPMGroups | Select-Object -First 1 

        id                        : XXXXXXXXXXXXXXXXXXXXXXXXX
        name                      : My Company
        description               : 
        fullPathName              : My Company
        numberOfPhysicalComputers : 0
        numberOfRegisteredUsers   : 0
        createdBy                 : XXXXXXXXXXXXXXXXXXXXXXXXX
        created                   : 1360247401336
        lastModified              : 1639056401576
        policySerialNumber        : 718B-09/04/2023 12:56:58 775
        policyDate                : 1693832218775
        customIpsNumber           : 
        domain                    : @{id=XXXXXXXXXXXXXXXXXXXXXXXXX; name=Default}
        policyInheritanceEnabled  : False

        Gets the first group of the list of groups
#>

    [CmdletBinding()]
    param()

    begin {
        $session = Initialize-SEPMSession
        $endpoint = Get-SEPMApiEndpoint -OperationName 'Get-SEPMGroups'
    }

    process {
        # QueryString parameters for pagination
        $pageParams = @{
            pageSize  = 25
            pageIndex = 1
        }

        # Invoke the request
        $allResults = @()
        do {
            $resp = Invoke-SepmEndpoint -Endpoint $endpoint -Session $session -AdditionalQueryParams $pageParams

            # Process the response
            $allResults += $resp.content

            # Increment the page index
            $pageParams.pageIndex++
        } until ($resp.lastPage -eq $true)

        # return the response
        Write-Output $allResults -NoEnumerate
    }
}
