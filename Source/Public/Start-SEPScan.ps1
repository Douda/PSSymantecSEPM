function Start-SEPScan {
    <#
    .SYNOPSIS
        Sends Active Scan command to the specified computer(s) or group(s)
    .DESCRIPTION
        Sends a command from SEPM to SEP endpoints to request an active scan on the endpoint(s)
    .PARAMETER ComputerName
        Specifies the name of the computer for which you want to send the command. 
        Accepts pipeline input by Value and ByPropertyName
    .PARAMETER GroupName
        Specifies the group full path name for which you want to send the command
    .PARAMETER ActiveScan
        Specifies the type of scan to send to the endpoint(s)
        Valid values are ActiveScan and FullScan
        By default, the ActiveScan switch is used
    .PARAMETER FullScan
        Specifies the type of scan to send to the endpoint(s)
        Valid values are ActiveScan and FullScan
    .EXAMPLE
        PS C:\PSSymantecSEPM> Start-SEPScan -ComputerName MyComputer01 -ActiveScan

        Sends an active scan command to the specified computer MyComputer01
    .EXAMPLE
        "MyComputer1","MyComputer2" | Start-SEPScan

        Sends an active scan command to the specified computers MyComputer1 & MyComputer2 via pipeline
        By default, the ActiveScan switch is used
    .EXAMPLE
        Start-SEPScan -GroupName "My Company\EMEA\Workstations" -fullscan

        Sends a fullscan command to all endpoints part of the group "My Company\EMEA\Workstations"
#>
    [CmdletBinding(
        DefaultParameterSetName = 'ComputerNameActiveScan'
    )]
    Param (
        # ComputerName
        [Parameter(
            ParameterSetName = 'ComputerNameActiveScan',
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [Parameter(
            ParameterSetName = 'ComputerNameFullScan',
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [Alias("Hostname", "DeviceName", "Device", "Computer")]
        [String]
        $ComputerName,

        # group name
        [Parameter(
            ParameterSetName = 'GroupNameActiveScan',
            ValueFromPipelineByPropertyName = $true
        )]
        [Parameter(
            ParameterSetName = 'GroupNameFullScan',
            ValueFromPipelineByPropertyName = $true
        )]
        [Alias("Group")]
        [String]
        $GroupName,

        # ActiveScan
        [Parameter(ParameterSetName = 'ComputerNameActiveScan')]
        [Parameter(ParameterSetName = 'GroupNameActiveScan')]
        [switch]
        $ActiveScan,

        # FullScan
        [Parameter(ParameterSetName = 'ComputerNameFullScan')]
        [Parameter(ParameterSetName = 'GroupNameFullScan')]
        [switch]
        $FullScan
    )

    begin {
        # initialize the configuration
        $test_token = Test-SEPMAccessToken
        if (-not $test_token){
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

            if ($ActiveScan) {
                $URI = $script:BaseURLv1 + "/command-queue/activescan"
            }
            if ($FullScan) {
                $URI = $script:BaseURLv1 + "/command-queue/fullscan"
            }

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

            # Invoke the request params
            $params = @{
                Method  = 'POST'
                Uri     = $URI
                headers = $headers
            }
    
            $resp = Invoke-ABRestMethod -params $params

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
                    
                    $resp = Invoke-ABRestMethod -params $params
                
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

            if ($ActiveScan) {
                $URI = $script:BaseURLv1 + "/command-queue/activescan"
            }
            if ($FullScan) {
                $URI = $script:BaseURLv1 + "/command-queue/fullscan"
            }

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
        
                # Invoke the request params
                $params = @{
                    Method  = 'POST'
                    Uri     = $URI
                    headers = $headers
                }

                # Send command to each computers in the group
                $resp = Invoke-ABRestMethod -params $params
                $AllResp += $resp
            }
            
            # return the response
            return $AllResp
        }
    }
}