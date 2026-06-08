function Get-SEPMLatestDefinition {
    <#
    .SYNOPSIS
        Get AV Def Latest Info
    .DESCRIPTION
        Gets the latest revision information for antivirus definitions from Symantec Security Response.
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPMLatestDefinition

        contentName publishedBySymantec publishedBySEPM
        ----------- ------------------- ---------------
        AV_DEFS     9/4/2023 rev. 2     9/4/2023 rev. 2

        Gets the latest revision information for antivirus definitions from Symantec Security Response.
#>

    [CmdletBinding()]
    param()

    begin {
        $session = Initialize-SEPMSession
        $URI = $session.BaseURLv1 + "/content/avdef/latest"

    }

    process {
        $resp = Invoke-SepmApi -Method GET -Uri $URI -Session $session

        return $resp
    }
}
