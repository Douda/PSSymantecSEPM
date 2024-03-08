function Get-SEPMLicense {
    <#
    .SYNOPSIS
        Get SEP License Info
    .DESCRIPTION
        Get SEP License Info
    .PARAMETER SkipCertificateCheck
        Skip certificate check
    .PARAMETER Summary
        Get the summary of the license information
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPMLicense

        serialNumber       : BXXXXXXXXXX
        licenseType        : 2
        seats              : 10000
        startDate          : 1641562400000
        expireDate         : 1757393999000
        endDate            : 1757393999000
        associatedLicenses : 
        productName        : Symantec Endpoint Security Complete, Subscription License
        keyNames           : {SES, SES_SVR, scs_content, SEP_APP_ISOLATION…}

        Gets the license information for the SEPM
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPMLicense -Summary

        license_type            : PAID
        ended                   : False
        service_end_date        : 1757393999000
        service_expiration_date : 1757393999000
        serial_number           : BXXXXXXXXXX
        ordered_quantity        : 10000
        unexpired_seats         : 10000

        Gets the summary of the license information for the SEPM
#>

    [CmdletBinding()]
    param (
        # Skip certificate check
        [Parameter()]
        [switch]
        $SkipCertificateCheck,

        # Summary
        [Parameter()]
        [switch]
        $Summary
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
        $URI = $script:BaseURLv1 + "/licenses"
        $headers = @{
            "Authorization" = "Bearer " + $script:accessToken.token
            "Content"       = 'application/json'
        }
    }

    process {
        #If the -Summary switch is used, then we will only return the summary of the license information
        if ($Summary) {
            $URI = $script:BaseURLv1 + "/licenses/summary"
        }

        # prepare the parameters
        $params = @{
            Method  = 'GET'
            Uri     = $URI
            headers = $headers
        }
    
        $resp = Invoke-ABRestMethod -params $params

        # Add a PSTypeName to the object
        if ($Summary) {
            $resp.PSObject.TypeNames.Insert(0, 'SEPM.LicenseSummaryInfo')
        } else {
            $resp.PSObject.TypeNames.Insert(0, 'SEPM.LicenseInfo')
        }
        
        return $resp
    }
}