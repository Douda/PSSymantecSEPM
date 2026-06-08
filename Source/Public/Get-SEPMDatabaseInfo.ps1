function Get-SEPMDatabaseInfo {
    <#
    .SYNOPSIS
        Gets the database infromation of local site.
    .DESCRIPTION
        Gets the database infromation of local site
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
    param()
    begin {
        $session = Initialize-SEPMSession
        $URI = $session.BaseURLv1 + "/admin/database"

    }

    process {
        $resp = Invoke-SepmApi -Method GET -Uri $URI -Session $session

        return $resp
    }
}
