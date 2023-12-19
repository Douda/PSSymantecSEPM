function Get-SEPClientStatus {
    <#
    .SYNOPSIS
        Gets a list and count of the online and offline clients.
    .DESCRIPTION
        Gets a list and count of the online and offline clients.
    .PARAMETER SkipCertificateCheck
        Skip certificate check
    .EXAMPLE
        C:\PSSymantecSEPM> Get-SEPClientStatus

        lastUpdated     clientCountStatsList
        -----------     --------------------
        1693910248728   {@{status=ONLINE; clientsCount=212}, @{status=OFFLINE; clientsCount=48}}

        Gets a list and count of the online and offline clients.
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
        $URI = $script:BaseURLv1 + "/stats/client/onlinestatus"
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
        $resp.clientCountStatsList | ForEach-Object {
            $_.PSTypeNames.Insert(0, "SEP.clientStatusList")
        }

        return $resp.clientCountStatsList
    }
}