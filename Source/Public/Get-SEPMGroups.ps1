function Get-SEPMGroups {
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
        $SkipCertificateCheck
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
    }

    process {
        # prepare the parameters
        $params = @{
            Method  = 'GET'
            Uri     = $URI
            headers = $headers
        }

        # QueryString parameters for pagination
        $QueryStrings = @{
            pageSize  = 25
            pageIndex = 1
        }
    
        # Invoke the request
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
                $allResults += $resp.content

                # Increment the page index & update URI
                $QueryStrings.pageIndex++
                $URI = Build-SEPMQueryURI -BaseURI $URI -QueryStrings $QueryStrings
            } catch {
                Write-Warning -Message "Error: $_"
            }
        } until ($resp.lastPage -eq $true)

        # Add a PSTypeName to the object
        $allResults | ForEach-Object {
            $_.PSObject.TypeNames.Insert(0, 'SEPM.GroupInfo')
        }

        # return the response
        return $allResults
    }
}