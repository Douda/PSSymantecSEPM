function Remove-SEPMGroup {
    <#
    .SYNOPSIS
        Deletes a SEPM group
    .DESCRIPTION
        Deletes a SEPM group by its full path name.
        Requires the GroupName and ParentGroup to locate the group.
    .PARAMETER GroupName
        Specifies the name of the group to delete
    .PARAMETER ParentGroup
        Specifies the full path name of the parent group
        Full path name is the group name with the parent groups separated by backslash
        "My Company\EMEA\Workstations"
    .EXAMPLE
        Remove-SEPMGroup -GroupName "Win7" -ParentGroup "My Company\EMEA\Workstations"

        Deletes the group Win7 under My Company\EMEA\Workstations
    .EXAMPLE
        Remove-SEPMGroup -GroupName "TestGroup" -ParentGroup "My Company"

        Deletes the group TestGroup directly under My Company
    #>

    [CmdletBinding()]
    param (
        # group name
        [Parameter(
            ValueFromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [Alias("Group")]
        [String]
        $GroupName,

        # Parent group
        [Parameter(
            ValueFromPipelineByPropertyName = $true
        )]
        [String]
        $ParentGroup
    )

    begin {
        $session = Initialize-SEPMSession
        $endpoint = Get-SEPMApiEndpoint -OperationName 'Remove-SEPMGroup'

        # Get all groups from SEPM
        $allGroups = Get-SEPMGroups
    }

    process {
        # Build the full path and find the group's own ID
        $fullPathName = "$ParentGroup\$GroupName"
        $group = $allGroups | Where-Object { $_.fullPathName -eq $fullPathName } | Select-Object -First 1

        if (-not $group -or [string]::IsNullOrEmpty($group.id)) {
            $message = "Group '$fullPathName' not found. Please check the group name and parent group and try again."
            $message += " Following group format is expected: 'My Company\group\subgroup'"
            Write-Error $message -ErrorAction Continue
            return
        }

        $resp = Invoke-SepmEndpoint -Endpoint $endpoint -Session $session -PathIds @($group.id)
        return $resp
    }
}
