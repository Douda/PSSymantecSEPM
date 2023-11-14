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
    .PARAMETER SkipCertificateCheck
        Skip certificate check
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPMPoliciesSummary

        content          :  {@{sources=System.Object[]; enabled=True; desc=Created automatically during product  ...}}
        size             : 136
        number           : 0
        sort             :
        numberOfElements : 136
        totalElements    : 136
        totalPages       : 1
        lastPage         : True
        firstPage        : True

        Get policy statistics for all policies and its assigned groups
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPMPoliciesSummary -PolicyType fw

        Get policy statistics for firewall policies and its assigned groups
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
            'msl', 
            'upgrade'
        )]
        [string]
        $PolicyType,

        # Skip certificate check
        [Parameter()]
        [switch]
        $SkipCertificateCheck
    )

    begin {
        # initialize the configuration
        $test_token = Test-SEPMAccessToken
        if (-not $test_token) {
            Get-SEPMAccessToken | Out-Null
        }
        if ($SkipCertificateCheck) {
            $script:SkipCert = $true
        }
        $URI = $script:BaseURLv1 + "/policies/summary"
        $headers = @{
            "Authorization" = "Bearer " + $script:accessToken.token
            "Content"       = 'application/json'
        }
        # Get the list of groups and IDs to inject into the response
        $groups = Get-SEPMGroups
    }

    process {
        if (-not $PolicyType) {
            $allResults = @()
    
            # Invoke the request
            do {
                try {
                    # prepare the parameters
                    $params = @{
                        Method  = 'GET'
                        Uri     = $URI
                        headers = $headers
                    }

                    $resp = Invoke-ABRestMethod -params $params
                    
                    # Add group FullPath to the response from their Group ID for ease of use
                    # Parsing every response object
                    foreach ($policy in $resp.content) {
                        # Parsing every location this policy is applied to
                        foreach ($location in $policy.assignedtolocations) {
                            # Getting the group name from the group ID, and adding it to the response object
                            $group = $groups | Where-Object { $_.id -match $location.groupid }  | Get-Unique
                            $location | Add-Member -NotePropertyName "groupNameFullPath" -NotePropertyValue $group.fullPathName
                        }
                    }
                
                    # Process the response
                    $allResults += $resp.content

                    # Increment the page index & update URI
                    $QueryStrings.pageIndex++
                    $URI = Build-SEPMQueryURI -BaseURI $URI -QueryStrings $QueryStrings
                } catch {
                    Write-Warning -Message "Error: $_"
                }
            } until ($resp.lastPage -eq $true)

            # return the response
            return $allResults
        }

        if ($PolicyType) {
            $URI = $script:BaseURLv1 + "/policies/summary" + "/" + $PolicyType
            $allResults = @()
        
            # prepare the parameters
            $params = @{
                Method  = 'GET'
                Uri     = $URI
                headers = $headers
            }
    
            # Invoke the request
            do {
                try {
                    # Invoke the request params
                    $params = @{
                        Method  = 'GET'
                        Uri     = $URI
                        headers = $headers
                    }
                    
                    $resp = Invoke-ABRestMethod -params $params

                    # Add group FullPath to the response from their Group ID for ease of use
                    # Parsing every response object
                    foreach ($policy in $resp.content) {
                        # Parsing every location this policy is applied to
                        foreach ($location in $policy.assignedtolocations) {
                            # Getting the group name from the group ID, and adding it to the response object
                            $group = $groups | Where-Object { $_.id -match $location.groupid }  | Get-Unique
                            $location | Add-Member -NotePropertyName "groupNameFullPath" -NotePropertyValue $group.fullPathName
                        }
                    }
                
                    # Process the response
                    $allResults += $resp.content

                    # Increment the page index & update URI
                    $QueryStrings.pageIndex++
                    $URI = Build-SEPMQueryURI -BaseURI $URI -QueryStrings $QueryStrings
                } catch {
                    Write-Warning -Message "Error: $_"
                }
            } until ($resp.lastPage -eq $true)

            # return the response
            return $allResults
        }
    }
}