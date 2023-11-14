function Get-SEPMLatestDefinition {
    <#
    .SYNOPSIS
        Get AV Def Latest Info
    .DESCRIPTION
        Gets the latest revision information for antivirus definitions from Symantec Security Response.
    .PARAMETER SkipCertificateCheck
        Skip certificate check
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPMLatestDefinition

        contentName publishedBySymantec publishedBySEPM
        ----------- ------------------- ---------------
        AV_DEFS     9/4/2023 rev. 2     9/4/2023 rev. 2

        Gets the latest revision information for antivirus definitions from Symantec Security Response.
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
        $URI = $script:BaseURLv1 + "/content/avdef/latest"
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