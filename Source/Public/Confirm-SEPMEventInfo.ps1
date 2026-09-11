function Confirm-SEPMEventInfo {
    <#
    .SYNOPSIS
        Acknowledge a critical event notification in SEPM.
    .DESCRIPTION
        Acknowledges a specified critical event by its event ID.
        A system administrator account is required for this REST API.

        Note: Not all critical event types can be acknowledged via the REST API.
        The SEPM API only supports acknowledging certain event types
        (e.g., Server Health Alert). Events such as software update
        notifications and system notifications will return an error and
        must be acknowledged through the SEPM console.
    .PARAMETER EventID
        The event ID to acknowledge, as returned by Get-SEPMEventInfo.
    .EXAMPLE
        PS C:\PSSymantecSEPM> $events = Get-SEPMEventInfo
        PS C:\PSSymantecSEPM> Confirm-SEPMEventInfo -EventID $events[0].eventId

        True

        Acknowledges the first critical event. Returns $true on success.
    .EXAMPLE
        PS C:\PSSymantecSEPM> Confirm-SEPMEventInfo -EventID "15B9BDBFAC1E000268F855FB4332BCC6"

        Confirm-SEPMEventInfo: Event '15B9BDBF...' could not be acknowledged via the SEPM REST API...
        False

        Attempting to acknowledge a non-acknowledgeable event type returns
        $false with a descriptive error.
    .OUTPUTS
        System.Boolean. Returns $true if the event was acknowledged
        successfully, $false otherwise.
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
        $endpoint = Get-SEPMApiEndpoint -OperationName 'Confirm-SEPMEventInfo'
    }

    process {
        try {
            $null = Invoke-SepmEndpoint -Endpoint $endpoint -Session $session -PathIds @($EventID)
            return $true
        } catch {
            # The transport throws on every failure. SEPM rejects the event types it cannot
            # acknowledge with its own message, and the Transport Error carries that message
            # through, so it is reported verbatim rather than matched against expected text.
            $msg = @"
Event '$EventID' could not be acknowledged via the SEPM REST API.
Only certain critical event types (e.g., Server Health Alert) support acknowledgement.
Events such as software update notifications and system notifications must be
acknowledged through the SEPM console (Monitors > Notifications).

$($_.Exception.Message)
"@
            Write-Error -Message $msg -ErrorId 'EventAcknowledgeFailed' -ErrorAction Continue
            return $false
        }
    }
}
