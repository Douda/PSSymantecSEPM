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
        if ($test_token -eq $false) {
            Get-SEPMAccessToken | Out-Null
        }
        $URI = $script:BaseURLv1 + "/events/critical"
        $headers = @{
            "Authorization" = "Bearer " + $script:accessToken.token
            "Content"       = 'application/json'
        }
    }

    process {
        $allResults = @()

        if (-not $ComputerName) {
            $ComputerName = ""
        }

        # URI query strings
        $QueryStrings = @{
            pageIndex = 1
            pageSize  = 100
        }

        # Construct the URI
        $builder = New-Object System.UriBuilder($URI)
        $query = [System.Web.HttpUtility]::ParseQueryString($builder.Query)
        foreach ($param in $QueryStrings.GetEnumerator()) {
            $query[$param.Key] = $param.Value
        }
        $builder.Query = $query.ToString()
        $URI = $builder.ToString()
    
        # Invoke the request
        # If the version of PowerShell is 6 or greater, then we can use the -SkipCertificateCheck parameter
        # else we need to use the Skip-Cert function if self-signed certs are being used.

        ############################################################################################################
        # As per documentation https://apidocs.securitycloud.symantec.com/#/doc?id=sepm_events                     #
        # Pagination is not yet implemented for this API. The response will contain all the events in the system.  #
        # Commenting pagination code for now.                                                                      #
        ############################################################################################################


        # do {
        #     try {
        #         # Invoke the request params
        #         $params = @{
        #             Method  = 'GET'
        #             Uri     = $URI
        #             headers = $headers
        #         }
        #         if ($script:accessToken.skipCert -eq $true) {
        #             if ($PSVersionTable.PSVersion.Major -lt 6) {
        #                 Skip-Cert
        #                 $resp = Invoke-RestMethod @params
        #             } else {
        #                 $resp = Invoke-RestMethod @params -SkipCertificateCheck
        #             }
        #         } else {
        #             $resp = Invoke-RestMethod @params
        #         } 
                
        #         # Process the response
        #         $allResults += $resp.content

        #         # Increment the page index & update URI
        #         $QueryStrings.pageIndex++
        #         $query = [System.Web.HttpUtility]::ParseQueryString($builder.Query)
        #         foreach ($param in $QueryStrings.GetEnumerator()) {
        #             $query[$param.Key] = $param.Value
        #         }
        #         $builder.Query = $query.ToString()
        #         $URI = $builder.ToString()
        #     } catch {
        #         Write-Warning -Message "Error: $_"
        #     }
        # } until ($resp.lastPage -eq $true)

        ###################################
        # Code without pagination for now #
        ###################################
        try {
            # Invoke the request params
            $params = @{
                Method  = 'GET'
                Uri     = $URI
                headers = $headers
            }
            if ($script:accessToken.skipCert -eq $true) {
                if ($PSVersionTable.PSVersion.Major -lt 6) {
                    Skip-Cert
                    $resp = Invoke-RestMethod @params
                } else {
                    $resp = Invoke-RestMethod @params -SkipCertificateCheck
                }
            } else {
                $resp = Invoke-RestMethod @params
            } 
            
            # Process the response
            $allResults += $resp
        } catch {
            Write-Warning -Message "Error: $_"
        }

        # return the response
        return $allResults
    }
}