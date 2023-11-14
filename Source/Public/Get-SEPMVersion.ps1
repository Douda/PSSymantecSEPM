Function Get-SEPMVersion {
    <# 
    .SYNOPSIS
        Gets the current version of Symantec Endpoint Protection Manager.
    .DESCRIPTION
        Gets the current version of Symantec Endpoint Protection Manager. This function dot not require authentication.
    .PARAMETER SkipCertificateCheck
        Skip certificate check
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPMVersion

        API_SEQUENCE API_VERSION version
        ------------ ----------- -------
        230504014    14.3.7000   14.3.9816.7000

        Gets the current version of Symantec Endpoint Protection Manager.
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
        $URI = $script:BaseURLv1 + "/version"
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