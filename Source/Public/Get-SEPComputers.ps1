function Get-SEPComputers {
    <#
    .SYNOPSIS
        Gets the information about the computers in a specified domain
    .DESCRIPTION
        Gets the information about the computers in a specified domain. either from computer names or group names
    .PARAMETER ComputerName
        Specifies the name of the computer for which you want to get the information. Supports wildcards
    .PARAMETER GroupName
        Specifies the group full path name for which you want to get the information.        
    .EXAMPLE
        Get-SEPComputers

        Gets computer details for all computers in the domain
    .EXAMPLE
        "MyComputer1","MyComputer2" | Get-SEPComputers

        Gets computer details for the specified computer MyComputer via pipeline
    .EXAMPLE
        Get-SEPComputers -ComputerName "MyComputer*"

        Gets computer details for all computer names starting by MyComputer
    .EXAMPLE
        Get-SEPComputers -GroupName "My Company\EMEA\Workstations"

        Gets computer details for all computers in the specified group MyGroup
#>
    [CmdletBinding(
        DefaultParameterSetName = 'ComputerName'
    )]
    Param (
        # ComputerName
        [Parameter(
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'ComputerName'
        )]
        [Alias("Hostname", "DeviceName", "Device", "Computer")]
        [String]
        $ComputerName,

        # group name
        [Parameter(
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'GroupName'
        )]
        [Alias("Group")]
        [String]
        $GroupName
    )

    begin {
        # initialize the configuration
        $test_token = Test-SEPMAccessToken
        if ($test_token -eq $false) {
            Get-SEPMAccessToken | Out-Null
        }
        
        $headers = @{
            "Authorization" = "Bearer " + $script:accessToken.token
            "Content"       = 'application/json'
        }
    }

    process {

        if ($ComputerName) {
            $allResults = @()
            $URI = $script:BaseURLv1 + "/computers"

            # URI query strings
            $QueryStrings = @{
                sort         = "COMPUTER_NAME"
                pageIndex    = 1
                pageSize     = 100
                computerName = $ComputerName
            }

            # Construct the URI
            $builder = New-Object System.UriBuilder($URI)
            $query = [System.Web.HttpUtility]::ParseQueryString($builder.Query)
            foreach ($param in $QueryStrings.GetEnumerator()) {
                $query[$param.Key] = $param.Value
            }
            $builder.Query = $query.ToString()
            $URI = $builder.ToString()
    
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

        #Using computer name API call then filtering
        elseif ($GroupName) {
            $allResults = @()
            $URI = $script:BaseURLv1 + "/computers"

            # URI query strings
            $QueryStrings = @{
                sort         = "COMPUTER_NAME"
                pageIndex    = 1
                pageSize     = 100
                computerName = $ComputerName
            }

            # Construct the URI
            $builder = New-Object System.UriBuilder($URI)
            $query = [System.Web.HttpUtility]::ParseQueryString($builder.Query)
            foreach ($param in $QueryStrings.GetEnumerator()) {
                $query[$param.Key] = $param.Value
            }
            $builder.Query = $query.ToString()
            $URI = $builder.ToString()
    
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

            # Filtering
            $allResults = $allResults | Where-Object { $_.group.name -eq $GroupName }

            # return the response
            return $allResults
        }

        # Using groupname API call
        elseif ($GroupName) {
            $allResults = @()
                
            # Get SEP Group ID from group name
            $GroupID = Get-SEPMGroups | Where-Object { $_.fullPathName -eq $GroupName } | Select-Object -ExpandProperty id
            $URI = $script:BaseURLv1 + "/groups/$GroupID/computers"

            # URI query strings
            $QueryStrings = @{
                pageIndex = 1
                sort      = "COMPUTER_NAME"
            }

            # Construct the URI
            $builder = New-Object System.UriBuilder($URI)
            $query = [System.Web.HttpUtility]::ParseQueryString($builder.Query)
            foreach ($param in $QueryStrings.GetEnumerator()) {
                $query[$param.Key] = $param.Value
            }
            $builder.Query = $query.ToString()
            $URI = $builder.ToString()
    
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

        else {
            $allResults = @()
            $URI = $script:BaseURLv1 + "/computers"

            # URI query strings
            $QueryStrings = @{
                sort      = "COMPUTER_NAME"
                pageIndex = 1
                pageSize  = 100
            }

            # Construct the URI
            $builder = New-Object System.UriBuilder($URI)
            $query = [System.Web.HttpUtility]::ParseQueryString($builder.Query)
            foreach ($param in $QueryStrings.GetEnumerator()) {
                $query[$param.Key] = $param.Value
            }
            $builder.Query = $query.ToString()
            $URI = $builder.ToString()
    
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