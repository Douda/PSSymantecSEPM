function Get-SEPClientDefVersions {
    <#
    .SYNOPSIS
        Gets a list of clients for a group by content version.
    .DESCRIPTION
        Gets a list of clients for a group by content version.
    .PARAMETER SkipCertificateCheck
        Skip certificate check
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPClientDefVersions

        version             clientsCount
        -------             ------------
        2023-09-04 rev. 002           15
        2023-09-03 rev. 002            4
        2023-09-01 rev. 008            2
        2023-08-31 rev. 021            2
        2023-08-31 rev. 002            1
        2023-08-29 rev. 003            1

        Gets a list of clients grouped by content version.
    .EXAMPLE
        PS C:\PSSymantecSEPM> $definitionVersions = Get-SEPClientDefVersions
        PS C:\PSSymantecSEPM> $definitionVersions

        version             clientsCount
        -------             ------------
        2023-09-04 rev. 002           15
        2023-09-03 rev. 002            4
        2023-09-01 rev. 008            2
        2023-08-31 rev. 021            2
        2023-08-31 rev. 002            1
        2023-08-29 rev. 003            1

        PS C:\PSSymantecSEPM> ($definitionVersions | Where-Object version -eq "2023-09-03 rev. 002").GetComputerWithThisDefinition()

        computerName    ipAddresses    GroupName
        ------------    -----------    ---------
        Computer123     {10.0.70.126}  My Company\_Americas\Workstations
        Computer124     {10.1.19.127}  My Company\_EMEA\Workstations
        Computer125     {10.5.125.128} My Company\_APAC\Workstations
        Computer126     {10.9.38.110}  My Company\_LATAM\Workstations

        Gets a list of clients grouped by content version 
        Then gets the list of computers with a specified content version (2023-09-03 rev. 002), using the GetComputerWithThisDefinition() method.
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
        $URI = $script:BaseURLv1 + "/stats/client/content"
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
        $resp.clientDefStatusList | ForEach-Object {
            $_.PSTypeNames.Insert(0, "SEP.clientDefStatusList")
        }

        return $resp.clientDefStatusList
    }
}