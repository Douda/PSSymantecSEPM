function Get-SEPMPoliciesSummary {
    <#
    .SYNOPSIS
        Get summary of all or feature specific policies
    .DESCRIPTION
        Get the policy summary for specified policy type. 
        Also gets the list of groups to which the policies are assigned.
    .PARAMETER PolicyType
        The policy type for which the summary is to be retrieved. 
        The valid values are hid, exceptions, mem, ntr, av, fw, ips, lucontent, lu, hi, adc, msl, upgrade.

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
        $PolicyType
    )

    begin {
        # initialize the configuration
        $test_token = Test-SEPMAccessToken
        if ($test_token -eq $false) {
            Get-SEPMAccessToken | Out-Null
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
        
            # URI query strings
            $QueryStrings = @{}

            # Construct the URI
            $builder = New-Object System.UriBuilder($URI)
            $query = [System.Web.HttpUtility]::ParseQueryString($builder.Query)
            foreach ($param in $QueryStrings.GetEnumerator()) {
                $query[$param.Key] = $param.Value
            }
            $builder.Query = $query.ToString()
            $URI = $builder.ToString()

            $params = @{
                Method  = 'GET'
                Uri     = $URI
                headers = $headers
            }
    
            # Invoke the request
            # If the version of PowerShell is 6 or greater, then we can use the -SkipCertificateCheck parameter
            # else we need to use the Skip-Cert function if self-signed certs are being used.
            do {
                try {
                    # Invoke the request params
                    $params = @{
                        Method  = 'GET'
                        Uri     = $URI
                        headers = $headers
                    }
                    if ($script:accessToken.skipCert -eq $true) {
                        if ($PSVersionTable.PSVersion.Major -lt 6) {
                            Skip-Cert
                            $resp = Invoke-RestMethod @params
                        } else {
                            $resp = Invoke-RestMethod @params -SkipCertificateCheck
                        }
                    } else {
                        $resp = Invoke-RestMethod @params
                    }
                    
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
                    $query = [System.Web.HttpUtility]::ParseQueryString($builder.Query)
                    foreach ($param in $QueryStrings.GetEnumerator()) {
                        $query[$param.Key] = $param.Value
                    }
                    $builder.Query = $query.ToString()
                    $URI = $builder.ToString()
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
        
            # URI query strings
            $QueryStrings = @{}

            # Construct the URI
            $builder = New-Object System.UriBuilder($URI)
            $query = [System.Web.HttpUtility]::ParseQueryString($builder.Query)
            foreach ($param in $QueryStrings.GetEnumerator()) {
                $query[$param.Key] = $param.Value
            }
            $builder.Query = $query.ToString()
            $URI = $builder.ToString()

            $params = @{
                Method  = 'GET'
                Uri     = $URI
                headers = $headers
            }


    
            # Invoke the request
            # If the version of PowerShell is 6 or greater, then we can use the -SkipCertificateCheck parameter
            # else we need to use the Skip-Cert function if self-signed certs are being used.
            do {
                try {
                    # Invoke the request params
                    $params = @{
                        Method  = 'GET'
                        Uri     = $URI
                        headers = $headers
                    }
                    if ($script:accessToken.skipCert -eq $true) {
                        if ($PSVersionTable.PSVersion.Major -lt 6) {
                            Skip-Cert
                            $resp = Invoke-RestMethod @params
                        } else {
                            $resp = Invoke-RestMethod @params -SkipCertificateCheck
                        }
                    } else {
                        $resp = Invoke-RestMethod @params
                    } 

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
                    $query = [System.Web.HttpUtility]::ParseQueryString($builder.Query)
                    foreach ($param in $QueryStrings.GetEnumerator()) {
                        $query[$param.Key] = $param.Value
                    }
                    $builder.Query = $query.ToString()
                    $URI = $builder.ToString()
                } catch {
                    Write-Warning -Message "Error: $_"
                }
            } until ($resp.lastPage -eq $true)

            # return the response
            return $allResults
        }
    }
}