function Confirm-SEPMEventInfo {
    <# # TODO add examples once finished
    .SYNOPSIS
        Post Acknowledgement For Notification
    .DESCRIPTION
        Acknowledges a specified event for a given event ID.
        A system administrator account is required for this REST API.
    .PARAMETER EventID
        The event ID to acknowledge.
    .PARAMETER SkipCertificateCheck
        Skip certificate check
    .EXAMPLE
        PS C:\PSSymantecSEPM> $SEPMEvents = Confirm-SEPMEventInfo -eventID 30D8A67F0A6606220DEB5989DC3FAC50
#>

    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true
        )]
        [string]
        $EventID,

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
        $URI = $script:BaseURLv1 + "/events/acknowledge/$eventID"
        $headers = @{
            "Authorization" = "Bearer " + $script:accessToken.token
            "Content"       = 'application/json'
        }
    }

    process {
        $params = @{
            Method  = 'POST'
            Uri     = $URI
            headers = $headers
        }
        
        $resp = Invoke-ABRestMethod -params $params

        # return the response
        return $resp
    }
}