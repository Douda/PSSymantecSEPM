function Remove-SEPMGroup {
    <# TODO Update the help
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
    .PARAMETER SkipCertificateCheck
        Skip certificate check
    .EXAMPLE
        Remove-SEPMGroup -GroupName "Win7" -ParentGroup "My Company\EMEA\Workstations"

        Creates a new group Win7 under the group My Company\EMEA\Workstations
    .EXAMPLE
        Remove-SEPMGroup -GroupName "Win 10" -ParentGroup "My Company\EMEA\Workstations" -EnabledInheritance

        Creates a new group Win 10 under the group My Company\EMEA\Workstations and enables inheritance
    #>

    [CmdletBinding()]
    param (
        # Skip certificate check
        [Parameter()]
        [switch]
        $SkipCertificateCheck,

        # group name
        [Parameter(
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateScript({
                if ([string]::IsNullOrEmpty($ParentGroup)) {
                    throw "The -GroupName parameter requires the -ParentGroup parameter to be set."
                }
                return $true
            })]
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
        # initialize the configuration
        $test_token = Test-SEPMAccessToken
        if (-not $test_token) {
            Get-SEPMAccessToken | Out-Null
        }
        if ($SkipCertificateCheck) {
            $script:SkipCert = $true
        }
        $URI = $script:BaseURLv1 + "/groups"
        $headers = @{
            "Authorization" = "Bearer " + $script:accessToken.token
            "Content"       = 'application/json'
        }
        # Get all groups from SEPM
        $allGroups = Get-SEPMGroups
    }

    process {
        # Get the group ID of the destination group
        $ParentGroupID = $allGroups | Where-Object { $_.fullPathName -eq $ParentGroup } | Select-Object -ExpandProperty id
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

        # prepare the parameters
        $params = @{
            Method      = 'POST'
            Uri         = $URI + "/$ParentGroupID"
            headers     = $headers
            contenttype = 'application/json'
            body        = $body | ConvertTo-Json
        }

        # TODO For testing only - remove this
        # $body | ConvertTo-Json -Depth 100 | Out-File .\Data\PolicyStructure.json -Force
    
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