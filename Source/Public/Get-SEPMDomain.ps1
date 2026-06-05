function Get-SEPMDomain {
    <#
    .SYNOPSIS
        Gets a list of all accessible domains
    .DESCRIPTION
        Gets a list of all accessible domains
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPMDomain

        id                 : XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
        name               : Default
        description        : 
        createdTime        : 1360247301316
        enable             : True
        companyName        : 
        contactInfo        : 
        administratorCount : 15

        Gets a list of all accessible domains
#>

    [CmdletBinding()]
    param()

    begin {
        $session = Initialize-SEPMSession
        $URI = $session.BaseURLv1 + "/domains"

    }

    process {
        # prepare the parameters
        $params = @{
            Session = $session
            Method  = 'GET'
            Uri     = $URI
        }
    
        $resp = Invoke-ABRestMethod -params $params

        # Add a PSTypeName to the object
        $resp.PSObject.TypeNames.Insert(0, 'SEPM.DomainInfo')

        return $resp
    }
}
