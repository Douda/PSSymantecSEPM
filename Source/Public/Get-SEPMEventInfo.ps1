function Get-SEPMEventInfo {
    <#
    .SYNOPSIS
        Gets the information about the computers in a specified domain
    .DESCRIPTION
        Gets the information about the computers in a specified domain. 
        A system administrator account is required for this REST API.
    .EXAMPLE
        PS C:\PSSymantecSEPM> $SEPMEvents = Get-SEPMEventInfo

        lastUpdated     totalUnacknowledgedMessages     criticalEventsInfoList
        -----------     ---------------------------     ----------------------
        1693911276712                        4906       {@{eventId=XXXXXXXXXXXXXXXXXXXXXXXXX; eventDateTime=2023-08-12 19:22:21.0...

        PS C:\PSSymantecSEPM> $SEPMEvents.criticalEventsInfoList | Select-Object -First 1

        eventId       : XXXXXXXXXXXXXXXXXXXXXXXXX
        eventDateTime : 2023-08-12 19:22:21.0
        subject       : CRITICAL: OLD SONAR DEFINITIONS
        message       : 306 computers found with SONAR definitions older than 7 days.
        acknowledged  : 0

        Example of an event gathered from the SEPM server.
#>

    begin {
        # initialize the configuration
        $test_token = Test-SEPMAccessToken
        if (-not $test_token){
            Get-SEPMAccessToken | Out-Null
        }
        $URI = $script:BaseURLv1 + "/events/critical"
        $headers = @{
            "Authorization" = "Bearer " + $script:accessToken.token
            "Content"       = 'application/json'
        }
    }

    process {
        # Invoke the request params
        $params = @{
            Method  = 'GET'
            Uri     = $URI
            headers = $headers
        }

        $resp = Invoke-ABRestMethod -params $params

        # return the response
        return $resp
    }
}