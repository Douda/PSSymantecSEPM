function Get-SEPMDomain {
    <#
    .SYNOPSIS
        Gets a list of all accessible domains
    .DESCRIPTION
        Gets a list of all accessible domains
    .PARAMETER SkipCertificateCheck
        Skip certificate check
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPMDomain

        id                 : XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
        name               : Default
        description        : 
        createdTime        : 1360247301316
        enable             : True
        companyName        : 
        contactInfo        : 
        administratorCount : 15

        Gets a list of all accessible domains
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
        $URI = $script:BaseURLv1 + "/domains"
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
    
        $resp = Invoke-ABRestMethod -params $params

        # Add a PSTypeName to the object
        $resp.PSObject.TypeNames.Insert(0, 'SEPM.DomainInfo')

        return $resp
    }
}