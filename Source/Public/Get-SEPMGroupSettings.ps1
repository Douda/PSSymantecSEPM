function Get-SEPMGroupSettings {
    <#
    .SYNOPSIS
        Gets a group list
    .DESCRIPTION
        Gets a group list
    .PARAMETER SkipCertificateCheck
        Skip certificate check
    .EXAMPLE
        PS C:\GitHub_Projects\PSSymantecSEPM> Get-SEPMGroups | Select-Object -First 1 

        id                        : XXXXXXXXXXXXXXXXXXXXXXXXX
        name                      : My Company
        description               : 
        fullPathName              : My Company
        numberOfPhysicalComputers : 0
        numberOfRegisteredUsers   : 0
        createdBy                 : XXXXXXXXXXXXXXXXXXXXXXXXX
        created                   : 1360247401336
        lastModified              : 1639056401576
        policySerialNumber        : 718B-09/04/2023 12:56:58 775
        policyDate                : 1693832218775
        customIpsNumber           : 
        domain                    : @{id=XXXXXXXXXXXXXXXXXXXXXXXXX; name=Default}
        policyInheritanceEnabled  : False

        Gets the first group of the list of groups
#>

    [CmdletBinding()]
    param (
        # Skip certificate check
        [Parameter()]
        [switch]
        $SkipCertificateCheck,

        [Parameter(Mandatory = $true)]
        $locationId,

        [Parameter(Mandatory = $true)]
        $groupId
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
        # $URI = $script:BaseURLv1 + "/groups"
        $headers = @{
            "Authorization" = "Bearer " + $script:accessToken.token
            "Content"       = 'application/json'
        }
    }

    process {
        # Location ID
        $URI = $script:BaseURLv1 + "/groups/$groupId/locations/$locationId/settings"

        # prepare the parameters
        $params = @{
            Method  = 'GET'
            Uri     = $URI
            headers = $headers
        }

        # Invoke the request
        try {
            # Invoke the request params
            $params = @{
                Method  = 'GET'
                Uri     = $URI
                headers = $headers
            }
                
            $resp = Invoke-ABRestMethod -params $params
        } catch {
            Write-Warning -Message "Error: $_"
        }


        # Add a PSTypeName to the object
        # $resp | ForEach-Object {
        #     $_.PSObject.TypeNames.Insert(0, 'SEPM.GroupInfo')
        # }

        # return the response
        return $resp
    }
}