function Update-SEPClientDefinitions {
    <#
    .SYNOPSIS
        Sends a command from SEPM to SEP endpoints to update content
    .DESCRIPTION
        Sends a command from SEPM to SEP endpoints to update content
    .PARAMETER ComputerName
        The name of the computer to send the command to
        cannot be used with GroupName
    .PARAMETER GroupName
        The name of the group to send the command to
        cannot be used with ComputerName
    .EXAMPLE
        Update-SEPClientDefinitions -ComputerName "Computer1"
        Sends a command to update content to Computer1
    .EXAMPLE
        "Computer1", "Computer2" | Update-SEPClientDefinitions
        Sends a command to update content to Computer1 and Computer2
    .EXAMPLE
        Update-SEPClientDefinitions -GroupName "My Company\EMEA\Workstations"
        Sends a command to update content to all computers in "My Company\EMEA\Workstations"
    .EXAMPLE
        Update-SEPClientDefinitions -GroupName "My Company\EMEA\Workstations" -IncludeSubGroups
        Sends a command to update content to all computers in "My Company\EMEA\Workstations" and all subgroups
    #>
    
    
    [CmdletBinding()]
    param (
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
        $GroupName,

        # switch parameter to include subgroups
        [Parameter(
            ParameterSetName = 'GroupName'
        )]
        [switch]
        $IncludeSubGroups
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
        if ($ComputerName) {
            # Get computer ID(s) from computer name(s)
            $ComputerIDList = @()
            foreach ($C in $ComputerName) {
                $ComputerID = Get-SEPComputers -ComputerName $C | Select-Object -ExpandProperty uniqueId
                $ComputerIDList += $ComputerID
            }

            $URI = $script:BaseURLv1 + "/command-queue/updatecontent"

            # URI query strings
            $QueryStrings = @{
                computer_ids = $ComputerIDList
            }

            # Construct the URI
            $URI = Build-SEPMQueryURI -BaseURI $URI -QueryStrings $QueryStrings
    
            # prepare the parameters
            $params = @{
                Method  = 'POST'
                Uri     = $URI
                headers = $headers
            }

            $resp = Invoke-ABRestMethod -params $params
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
            $URI = Build-SEPMQueryURI -BaseURI $URI -QueryStrings $QueryStrings
    
            # Get computer list
            do {
                try {
                    # prepare the parameters
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
                    $URI = Build-SEPMQueryURI -BaseURI $URI -QueryStrings $QueryStrings
                } catch {
                    Write-Warning -Message "Error: $_"
                }
            } until ($resp.lastPage -eq $true)

            # filter list by group name
            # if IncludeSubGroups is specified, then get all computers from subgroups
            if ($IncludeSubGroups) {
                # get all subgroups
                $allComputers = $allComputers | Where-Object { $_.group.name -like "$GroupName*" }
            } else {
                $allComputers = $allComputers | Where-Object { $_.group.name -eq $GroupName }
            }
            
            #################################################
            # 2. send command to all computers in the group #
            #################################################

            $URI = $script:BaseURLv1 + "/command-queue/updatecontent"
            $AllResp = @()
            
            # Send command to each computers in the group individually
            foreach ($id in $allComputers.uniqueId) {
                # URI query strings
                $QueryStrings = @{
                    computer_ids = $id
                }
    
                # Construct the URI
                $URI = Build-SEPMQueryURI -BaseURI $URI -QueryStrings $QueryStrings
        
                # prepare the parameters
                $params = @{
                    Method  = 'POST'
                    Uri     = $URI
                    headers = $headers
                }
                $resp = Invoke-ABRestMethod -params $params
                $AllResp += $resp
            }
            
            # return the response
            return $AllResp
        }
    }
}