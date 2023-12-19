function Get-SEPMDatabaseInfo {
    <#
    .SYNOPSIS
        Gets the database infromation of local site.
    .DESCRIPTION
        Gets the database infromation of local site
    .PARAMETER SkipCertificateCheck
        Skip certificate check
    .INPUTS
        None
    .OUTPUTS
        System.Object
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPMDatabaseInfo

        name                 : SQLSRV01
        description          : 
        address              : SQLSRV01
        instanceName         : 
        port                 : 1433
        type                 : Microsoft SQL Server
        version              : 12.00.5000
        installedBySepm      : False
        database             : sem5
        dbUser               : sem5
        dbPasswords          : 
        dbTLSRootCertificate : 

        Gets detailed information on the database of the local site 
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
        $URI = $script:BaseURLv1 + "/admin/database"
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
        $resp.PSObject.TypeNames.Insert(0, 'SEPM.DatabaseInfo')

        return $resp
    }
}