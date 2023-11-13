function Send-SEPMCommandQuarantine {
    <#
    .SYNOPSIS
        Send a quarantine/unquarantine command to SEP endpoints
    .DESCRIPTION
        Send a quarantine/unquarantine command to SEP endpoints
    .PARAMETER ComputerName
        The name of the computer to send the command to
        Cannot be used with GroupName
    .PARAMETER GroupName
        The name of the group to send the command to
        Cannot be used with ComputerName
        Does not include subgroups
    .PARAMETER Unquarantine
        Switch parameter to unquarantine the SEP client
    .EXAMPLE
        Send-SEPMCommandQuarantine -ComputerName "Computer1"
        Sends a command to quarantine Computer1
    .EXAMPLE
        "Computer1", "Computer2" | Send-SEPMCommandQuarantine
        Sends a command to quarantine Computer1 and Computer2
    .EXAMPLE
        Send-SEPMCommandQuarantine -GroupName "My Company\EMEA\Workstations\Site1"
        Sends a command to quarantine all computers in "My Company\EMEA\Workstations\Site1"
        Does not include subgroups
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

        # Unquarantine
        [Parameter()]
        [switch]
        $Unquarantine
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

            $URI = $script:BaseURLv1 + "/command-queue/quarantine"

            # URI query strings
            $QueryStrings = @{
                computer_ids = $ComputerIDList
            }

            # Add unquarantine if specified
            if ($Unquarantine) {
                $QueryStrings['undo'] = $true
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

        # If group name is specified
        elseif ($GroupName) {
            # Get group ID from group name
            $GroupID = Get-SEPMGroups | Where-Object { $_.fullPathName -eq $GroupName } | Select-Object -ExpandProperty id -First 1
            $URI = $script:BaseURLv1 + "/command-queue/quarantine"

            # URI query strings
            $QueryStrings = @{
                group_ids = $GroupID
            }

            # Add unquarantine if specified
            if ($Unquarantine) {
                $QueryStrings['undo'] = $true
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
    }
}