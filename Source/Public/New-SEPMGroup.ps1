function New-SEPMGroup {
    <#
    .SYNOPSIS
        Creates a new SEPM group
    .DESCRIPTION
        Creates a new SEPM group
        Requires the full path name of the parent group
    .PARAMETER GroupName
        Specifies the name of the group to create
    .PARAMETER ParentGroup
        Specifies the full path name of the parent group
        Full path name is the group name with the parent groups separated by backslash
        "My Company\EMEA\Workstations"
    .PARAMETER EnabledInheritance
        Specifies if the group should inherit the parent group's policies
    .EXAMPLE
        New-SEPMGroup -GroupName "Win7" -ParentGroup "My Company\EMEA\Workstations"

        Creates a new group Win7 under the group My Company\EMEA\Workstations
    .EXAMPLE
        New-SEPMGroup -GroupName "Win 10" -ParentGroup "My Company\EMEA\Workstations" -EnabledInheritance

        Creates a new group Win 10 under the group My Company\EMEA\Workstations and enables inheritance
    #>

    [CmdletBinding()]
    param (
        # Skip certificate check


        # group name
        [Parameter(
            ValueFromPipelineByPropertyName = $true
        )]
        [Alias("Group")]
        [String]
        $GroupName,

        # Parent group
        [Parameter(
            ValueFromPipelineByPropertyName = $true
        )]
        [String]
        $ParentGroup,

        # Enabled inheritance
        [Parameter(
            ValueFromPipelineByPropertyName = $true
        )]
        [Alias("Inherit")]
        [switch]
        $EnabledInheritance,

        # Group Description
        [Parameter(
            ValueFromPipelineByPropertyName = $true
        )]
        [String]
        $Description
    )

    begin {
        $session = Initialize-SEPMSession
        $URI = $session.BaseURLv1 + "/groups"

        # Get all groups from SEPM
        $allGroups = Get-SEPMGroups
    }

    process {
        # Get the group ID of the destination group
        $parent = $allGroups | Where-Object { $_.fullPathName -eq $ParentGroup } | Select-Object -First 1
        $ParentGroupID = if ($parent) { $parent.id } else { $null }
        if ([string]::IsNullOrEmpty($ParentGroupID)) {
            $message = "Group $GroupName not found. Please check the parent group name and try again."
            $message += "Following group format is expected: 'My Company\group\subgroup'"
            Write-Error $message
            return
        }

        # Body structure for the request
        $body = @{
            "inherits"    = $EnabledInheritance.ToBool()
            "name"        = $GroupName
            "description" = $Description
        }

        $patchUri = $URI + "/$ParentGroupID"
        $resp = Invoke-SepmApi -Method 'POST' -Uri $patchUri -Session $session `
            -Body (ConvertTo-SEPMJson -InputObject $body) -ContentType 'application/json'
        return $resp
    }
}
