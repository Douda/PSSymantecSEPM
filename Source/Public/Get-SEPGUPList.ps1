function Get-SEPGUPList {
    <#
    .SYNOPSIS
        Gets a list of group update providers
    .DESCRIPTION
        Gets a list of SEP clients acting as group update providers
    .PARAMETER SkipCertificateCheck
        Skip certificate check
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPGUPList

        Gets a list of GUPs clients
    .EXAMPLE
    PS C:\PSSymantecSEPM> Get-SEPGUPList | Select-Object Computername, AgentVersion, IpAddress, port

    computerName  agentVersion   ipAddress       port
    ------------  ------------   ---------       ----
    Server01      12.1.7454.7000 10.0.0.150      2967
    Server02      14.3.558.0000  10.1.0.150      2967
    Workstation01 12.1.7454.7000 192.168.0.1     2967
    Workstation02 14.3.558.0000  192.168.1.1     2967

    Gets a list of GUPs clients with specific properties
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
        $URI = $script:BaseURLv1 + "/gup/status"
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