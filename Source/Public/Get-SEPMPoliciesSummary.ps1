function Get-SEPMPoliciesSummary {
    <#
    .SYNOPSIS
        Get summary of all or feature specific policies
    .DESCRIPTION
        Get the policy summary for specified policy type. 
        Also gets the list of groups to which the policies are assigned.
    .PARAMETER PolicyType
        The policy type for which the summary is to be retrieved. 
        The valid values are hid, exceptions, mem, ntr, av, fw, ips, lu, hi, adc, msl, upgrade.
        If not specified, the summary for all policies is retrieved.
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPMPoliciesSummary

        Get policy statistics for all policies and its assigned groups
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPMPoliciesSummary -PolicyType fw

        Get policy statistics for firewall policies and its assigned groups
    .EXAMPLE
        PS C:\PSSymantecSEPM> $csvPoliciesSummary =  Get-SEPMPoliciesSummary | Select-Object -ExcludeProperty sources
        PS C:\PSSymantecSEPM> $csvPoliciesSummary | ConvertTo-FlatObject | Export-Csv C:\temp\test.csv
        PS C:\PSSymantecSEPM> $csvPoliciesSummary[0]

        enabled                                 : True
        desc                                    : 
        name                                    : Custom AV policy
        lastmodifiedtime                        : 1720096619241
        id                                      : DFDDEFB3AC1E4AEE7D3F8CC3968XXXXX
        domainid                                : 8D9FCF73C0A890F810856CF40E9XXXXX
        policytype                              : av
        subtype                                 : 
        assignedtocloudgroups                   : 
        assignedtolocations.1.groupId           : 4F492FD6AC15B5D55CA866FE6C3XXXXX
        assignedtolocations.1.defaultLocationId : FE77AFA8AC15B5D5607B79FDE94XXXXX
        assignedtolocations.1.locationIds.1     : FE77AFA8AC15B5D5607B79FDE94XXXXX
        assignedtolocations.1.groupNameFullPath : My Company\Workstations\Tamper\Block and do not log
        assignedtolocations.2.groupId           : BF9A0D8CAC15B5D534DB17F34E5XXXXX
        assignedtolocations.2.defaultLocationId : 39F318ABAC15B5D559E1014F7B0XXXXX
        assignedtolocations.2.locationIds.1     : 39F318ABAC15B5D559E1014F7B0XXXXX
        assignedtolocations.2.groupNameFullPath : My Company\Workstations\Tamper\Block and Log
        lastModifiedDate                        : 04/07/2023 12:36:59

        Export the list of all policies, its assigned groups, locations and other details to a CSV file
        Excludes the sources property from the output as it's empty by default
#>

    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet(
            'hid', 
            'exceptions', 
            'mem', 
            'ntr', 
            'av', 
            'fw', 
            'ips', 
            'lucontent', 
            'lu', 
            'hi', 
            'adc', 
            'msl', # Currently getting an error when trying to get this policy type
            # {"errorCode":"400","appErrorCode":"","errorMessage":"The policy type argument is invalid."}
            # TODO: Investigate this error
            'upgrade'
        )]
        [string]
        $PolicyType
    )

    begin {
        $session = Initialize-SEPMSession
        $URI = $session.BaseURLv1 + "/policies/summary"

        # Get the list of groups and IDs to inject into the response
        $groups = Get-SEPMGroups
    }

    process {
        if ($PolicyType) {
            $URI = $session.BaseURLv1 + "/policies/summary" + "/" + $PolicyType
        }

        # Invoke the request
        try {
            $resp = Invoke-SepmApi -Method GET -Uri $URI -Session $session
            # Add group FullPath to the response from their Group ID for ease of use
            # Parsing every response object
            foreach ($policy in $resp.content) {
                # Parsing every location this policy is applied to
                foreach ($location in $policy.assignedtolocations) {
                    # Getting the group name from the group ID, and adding it to the response object
                    $group = $groups | Where-Object { $_.id -match $location.groupid } | Get-Unique
                    $location | Add-Member -NotePropertyName "groupNameFullPath" -NotePropertyValue $group.fullPathName
                }
            }
        } catch {
            Write-Warning -Message "Error: $_"
        }
        

        # Add a PSTypeName to the object
        $resp.content | ForEach-Object {
            $_.PSTypeNames.Insert(0, 'SEPM.PolicySummary')
        }
            
        # return the response
        Write-Output $resp.content -NoEnumerate
    }
}
