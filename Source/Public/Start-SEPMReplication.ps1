function Start-SEPMReplication {
    <# TODO update help
    .SYNOPSIS
        Initiates replication with a remote site
    .DESCRIPTION
        Initiates replication with a remote site
    .PARAMETER partnerSiteName
        The name of the remote site to replicate with
    .EXAMPLE
        PS C:\PSSymantecSEPM> Start-SEPMReplication -partnerSiteName "Remote site Americas"

        code
        ----
        0

        Initiates replication with the remote site Americas. Response code 0 indicates success.
#>

    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $partnerSiteName

        # TODO known bug with SEPM API, these parameters are returning invalid option if not set to false 
        # [switch]
        # $logs,

        # [switch]
        # $ContentAndPackages
    )

    begin {
        $session = Initialize-SEPMSession
        $endpoint = Get-SEPMApiEndpoint -OperationName 'Start-SEPMReplication'
    }

    process {
        $resp = Invoke-SepmEndpoint -Endpoint $endpoint -Session $session -BoundParameters $PSBoundParameters
        return $resp
    }
}
