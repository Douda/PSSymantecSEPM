function Confirm-SEPMEventInfo {
    <# # TODO add examples once finished
    .SYNOPSIS
        Post Acknowledgement For Notification
    .DESCRIPTION
        Acknowledges a specified event for a given event ID.
        A system administrator account is required for this REST API.
    .PARAMETER EventID
        The event ID to acknowledge.
    .EXAMPLE
        PS C:\PSSymantecSEPM> $SEPMEvents = Confirm-SEPMEventInfo -eventID 30D8A67F0A6606220DEB5989DC3FAC50
#>

    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true
        )]
        [string]
        $EventID
    )

    begin {
        $session = Initialize-SEPMSession
        $URI = $session.BaseURLv1 + "/events/acknowledge/$eventID"

    }

    process {
        $resp = Invoke-SepmApi -Method POST -Uri $URI -Session $session

        # return the response
        return $resp
    }
}
