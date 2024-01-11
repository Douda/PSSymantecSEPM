function Move-SEPClientGroup {
    <#
    .SYNOPSIS
        Moves a computer to a different SEPM group
    .DESCRIPTION
        Moves a computer to a different SEPM group
        Gathers the hardwareKey of the computer and the group ID of the destination group
        and sends a PATCH request to the SEPM API 
    .PARAMETER ComputerName
        Specifies the name of the computer for which you want to get the information
    .PARAMETER GroupName
        Specifies the group full path name for which you want to get the information
        Full path name is the group name with the parent groups separated by backslash
        "My Company\EMEA\Workstations"
    .PARAMETER SkipCertificateCheck
        Skip certificate check
    .EXAMPLE
        Move-SEPClientGroup -ComputerName "MyComputer" -GroupName "My Company\EMEA\Workstations"

        Moves the computer MyComputer to the group My Company\EMEA\Workstations
    .EXAMPLE
        "MyComputer1","MyComputer2" | Move-SEPClientGroup -GroupName "My Company\EMEA\Workstations"

        Moves the computers MyComputer1 and MyComputer2 to the group My Company\EMEA\Workstations via pipeline
    #>

    [CmdletBinding()]
    param (
        # Skip certificate check
        [Parameter()]
        [switch]
        $SkipCertificateCheck,

        # ComputerName
        [Parameter(
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [Alias("Hostname", "DeviceName", "Device", "Computer")]
        [String]
        $ComputerName,

        # group name
        [Parameter(
            ValueFromPipelineByPropertyName = $true
        )]
        [Alias("Group")]
        [String]
        $GroupName
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
        $URI = $script:BaseURLv1 + "/computers"
        $headers = @{
            "Authorization" = "Bearer " + $script:accessToken.token
            "Content"       = 'application/json'
        }
        # Get all groups from SEPM
        $allGroups = Get-SEPMGroups
    }

    process {
        # Get the computer hardwareID
        $hardwareKey = Get-SEPComputers -ComputerName $ComputerName | Select-Object -ExpandProperty hardwareKey
        if ([string]::IsNullOrEmpty($hardwareKey)) {
            $message = "HardwareKey of computer $ComputerName not found. Please check the computer name and try again."
            Write-Error $message
            return
        }

        # Get the group ID of the destination group
        $groupID = $allGroups | Where-Object { $_.fullPathName -eq $GroupName } | Select-Object -ExpandProperty id
        if ([string]::IsNullOrEmpty($groupID)) {
            $message = "Group $GroupName not found. Please check the group name and try again."
            $message += "Following group format is expected: 'My Company\group\subgroup'"
            Write-Error $message
            return
        }

        # Body structure for the request
        $body = @(
            @{
                "group"       = @{
                    "id" = $groupID   
                }
                "hardwareKey" = $hardwareKey
            }
        ) 

        # prepare the parameters
        $params = @{
            Method      = 'PATCH'
            Uri         = $URI
            headers     = $headers
            contenttype = 'application/json'
            body        = $body | ForEach-Object { ConvertTo-Json @( $_ ) } # This way converts to JSON as array
        }
    
        # Invoke the request
        try {
            $resp = Invoke-ABRestMethod -params $params
        } catch {
            Write-Warning -Message "Error: $_"
        }

        # return the response
        return $resp
    }
}