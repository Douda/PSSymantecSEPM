function Get-SEPClientVersion {
    <#
    .SYNOPSIS
        Gets a list and count of clients by client product version.
    .DESCRIPTION
        Gets a list and count of clients by client product version.
    .PARAMETER SkipCertificateCheck
        Skip certificate check
    .EXAMPLE
        PS C:\PSSymantecSEPM> $SEPversions = Get-SEPClientVersion
        PS C:\PSSymantecSEPM> $SEPversions.clientVersionList

        version        clientsCount formattedVersion
        -------        ------------ ----------------
        11.0.6000.550             1 11.0.6 (11.0 MR6) build 550
        12.1.2015.2015            1 12.1.2 (12.1 RU2) build 2015
        12.1.6867.6400            1 12.1.6 (12.1 RU6 MP4) build 6867
        12.1.7004.6500            3 12.1.6 (12.1 RU6 MP5) build 7004
        12.1.7454.7000          177 12.1.7 (12.1 RU7) build 7454
        14.0.3752.1000           36 14.0.3 (14.0 RU3 MP7) build 1000
        14.2.1031.0100           21 14.2.1 (14.2 RU1) build 0100
        14.2.3335.1000            3 14.2.3 (14.2 RU3 MP3) build 1000
        14.3.510.0000            12 14.3 (14.3) build 0000
        14.3.558.0000             5 14.3 (14.3) build 0000

        Gets a list and count of clients by client product version.
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
        $URI = $script:BaseURLv1 + "/stats/client/version"
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
        return $resp
    }
}