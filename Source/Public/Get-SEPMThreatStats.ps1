function Get-SEPMThreatStats {
    <#
    .SYNOPSIS
        Gets threat statistics
    .DESCRIPTION
        Gets threat statistics
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPMThreatStats

        Stats
        -----
        @{lastUpdated=1693912098821; infectedClients=1}

        Gets threat statistics
#>

    [CmdletBinding()]
    param()

    begin {
        $session = Initialize-SEPMSession
        $endpoint = Get-SEPMApiEndpoint -OperationName 'Get-SEPMThreatStats'
    }

    process {
        $resp = Invoke-SepmEndpoint -Endpoint $endpoint -Session $session
        Write-Output $resp.Stats -NoEnumerate
    }
}
