function Get-SEPMLocationXML {
    <# TODO update help for Location
    .SYNOPSIS
        Gets a list of locations for a specific group
    .DESCRIPTION
        Gets a list of locations for a specific group
    .PARAMETER GroupID
        Mandatory parameter for the group ID
    .INPUTS
        System.String
    .OUTPUTS
        System.Object with the following properties:
            locationName
            locationId
            groupName
            groupId
            groupFullPathName
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPMLocationXML -GroupID "XXXXXXXX"

        name                  id
        ----                  --
        Default               33CE4894AC1485D12E3AAC763CF9A71B
        Location 1 - Internal 0CCB0536AC1485D1233F341B9495C3C5
        Location 2 - VPN      F5E857C9AC1485D13095A0D6E1CD5B25

        Gets the list of location names and their IDs for the specified group
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPMGroups | Get-SEPMLocationXML | ft

        locationName          locationId                       groupName                      groupId                          groupFullPathName
        ------------          ----------                       ---------                      -------                          -----------------
        Default               60B5C584AC17D44C6CC60471B7292FC4 My Company                     BDDDF2E6AC17D44C7007E1EA7851E110 My Company
        Default               60B5C584AC17D44C6CC60471B7292FC4 Default Group                  EA26D2D9AC17D44C532C651C62105B61 My Company\Default Group
        Default               60B5C584AC17D44C6CC60471B7292FC4 group 1                        10314F0DAC1485D157E3089CEB47D5BC My Company\group 1
        Default               60B5C584AC17D44C6CC60471B7292FC4 sub group 1                    6CB7099BAC1485D118EA465F45C4AE54 My Company\group 1\sub group 1

        Gets the list of location names and their IDs for all groups from the list of groups via pipeline
#>

    [CmdletBinding()]
    param (
        # Skip certificate check


        # GroupID
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [String]
        $GroupID,

        # LocationID
        [Parameter(
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [String]
        $LocationID
    )

    begin {
        $session = Initialize-SEPMSession
        $endpoint = Get-SEPMApiEndpoint -OperationName 'Get-SEPMLocationXML'
    }

    process {
        $resp = Invoke-SepmEndpoint -Endpoint $endpoint -Session $session -PathIds @($GroupID, $LocationID)

        return $resp
    }
}
