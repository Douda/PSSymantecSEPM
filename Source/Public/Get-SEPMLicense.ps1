function Get-SEPMLicense {
    <#
    .SYNOPSIS
        Get SEP License Info
    .DESCRIPTION
        Get SEP License Info
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


        # Summary
        [Parameter()]
        [switch]
        $Summary
    )

    begin {
        $session = Initialize-SEPMSession
        $URI = $session.BaseURLv1 + "/licenses"

    }

    process {
        #If the -Summary switch is used, then we will only return the summary of the license information
        if ($Summary) {
            $URI = $session.BaseURLv1 + "/licenses/summary"
        }

        $resp = Invoke-SepmApi -Method GET -Uri $URI -Session $session

        return $resp
    }
}
