function Start-SEPActiveScan {
    <# TODO - add help
    .SYNOPSIS
        Sends Active Scan command to the specified computer(s) or group(s)
    .DESCRIPTION
        Sends a command from SEPM to SEP endpoints to request an active scan on the endpoint(s)
    .PARAMETER ComputerName
        Specifies the name of the computer for which you want to send the command. 
        Accepts pipeline input by Value and ByPropertyName
    .PARAMETER GroupName
        Specifies the group full path name for which you want to send the command        
    .EXAMPLE
        PS C:\PSSymantecSEPM> Start-SEPActiveScan -ComputerName MyComputer01

        Sends an active scan command to the specified computer MyComputer01
    .EXAMPLE
        "MyComputer1","MyComputer2" | Start-SEPActiveScan

        Sends an active scan command to the specified computers MyComputer1 & MyComputer2 via pipeline
    .EXAMPLE
        Start-SEPActiveScan -GroupName "My Company\EMEA\Workstations"

        Sends an active scan command to all endpoints part of the group "My Company\EMEA\Workstations"
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
        # If specific computer name(s) are specified
        if ($ComputerName) {
            # Get computer ID(s) from computer name(s)
            $ComputerIDList = @()
            foreach ($C in $ComputerName) {
                $ComputerID = Get-SEPComputers -ComputerName $C | Select-Object -ExpandProperty uniqueId
                $ComputerIDList += $ComputerID
            }

            $URI = $script:BaseURLv1 + "/command-queue/activescan"

            # URI query strings
            $QueryStrings = @{
                computer_ids = $ComputerIDList
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
            try {
                # Invoke the request params
                $params = @{
                    Method  = 'POST'
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
                
            } catch {
                Write-Warning -Message "Error: $_"
            }

            # return the response
            return $resp
        }

        # If by groupname
        elseif ($GroupName) {
            #######################################
            # 1. finds all computers in the group #
            #######################################
            $allComputers = @()
            $URI = $script:BaseURLv1 + "/computers"

            # URI query strings
            $QueryStrings = @{
                sort         = "COMPUTER_NAME"
                pageIndex    = 1
                pageSize     = 100
                computerName = $ComputerName # empty string value to ensure the URI is constructed correctly & query all computers
            }

            # Construct the URI
            $builder = New-Object System.UriBuilder($URI)
            $query = [System.Web.HttpUtility]::ParseQueryString($builder.Query)
            foreach ($param in $QueryStrings.GetEnumerator()) {
                $query[$param.Key] = $param.Value
            }
            $builder.Query = $query.ToString()
            $URI = $builder.ToString()
    
            # Get computer list
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
                    $allComputers += $resp.content

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

            # filter list by group name
            $allComputers = $allComputers | Where-Object { $_.group.name -eq $GroupName }
            
            #################################################
            # 2. send command to all computers in the group #
            #################################################
            $URI = $script:BaseURLv1 + "/command-queue/activescan"
            $AllResp = @()
            
            foreach ($id in $allComputers.uniqueId) {
                # URI query strings
                $QueryStrings = @{
                    computer_ids = $id
                }
    
                # Construct the URI
                $builder = New-Object System.UriBuilder($URI)
                $query = [System.Web.HttpUtility]::ParseQueryString($builder.Query)
                foreach ($param in $QueryStrings.GetEnumerator()) {
                    $query[$param.Key] = $param.Value
                }
                $builder.Query = $query.ToString()
                $URI = $builder.ToString()
        
                # Send command to all computers in the group
                try {
                    # Invoke the request params
                    $params = @{
                        Method  = 'POST'
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
                    
                } catch {
                    Write-Warning -Message "Error: $_"
                    $AllResp += $_
                }
                $AllResp += $resp
            }
            
            # return the response
            return $AllResp
        }
    }
}