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


        # ComputerName
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [Alias("Hostname", "DeviceName", "Device", "Computer")]
        [String]
        $ComputerName,

        # group name
        [Parameter(
            Mandatory = $true
        )]
        [Alias("Group")]
        [String]
        $GroupName
    )

    begin {
        $session = Initialize-SEPMSession
        $URI = $session.BaseURLv1 + "/computers"

        # Get all groups from SEPM
        $allGroups = Get-SEPMGroups
    }

    process {
        # Get the computer hardwareID
        $computer = Get-SEPComputers -ComputerName $ComputerName | Select-Object -First 1
        $hardwareKey = if ($computer) { $computer.hardwareKey } else { $null }
        if ([string]::IsNullOrEmpty($hardwareKey)) {
            $message = "HardwareKey of computer $ComputerName not found. Please check the computer name and try again."
            Write-Error $message
            return
        }

        # Get the group ID of the destination group
        $group = $allGroups | Where-Object { $_.fullPathName -eq $GroupName } | Select-Object -First 1
        $groupID = if ($group) { $group.id } else { $null }
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

        $bodyJson = '[' + (($body | ConvertTo-Json) -join ',') + ']'
        $resp = Invoke-SepmApi -Method 'PATCH' -Uri $URI -Session $session `
            -Body $bodyJson -ContentType 'application/json'

        $fullResponse = [PSCustomObject]@{
            computerName        = $ComputerName
            computerHardwareKey = $hardwareKey
            targetGroup         = $GroupName
            responseCode        = $resp.responseCode
            responseMessage     = $resp.responseMessage
        }

        # Add a PSTypeName to the object
        $fullResponse.PSObject.TypeNames.Insert(0, 'SEPM.MoveClientGroupResponse')

        # return the response
        return $fullResponse
    }
}
