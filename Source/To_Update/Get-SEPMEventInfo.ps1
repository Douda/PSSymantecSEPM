Function Get-SEPMEventInfo {
    if ($PSVersionTable.PSVersion.Major -lt 6) {
        if ($null -ne $headers) {
            $URI = $BaseURL + "/events/critical"
            try {
                (Invoke-RestMethod -Method GET -Uri $URI -Headers $headers).criticalEventsInfoList
            } catch {
                "An error was found with this command. Please review the resultant error for details."
                $RESTError = Get-RestError($_)
                "Errors: $RESTError"
            }
        }
        if ($null -eq $headers) {
            Get-SEPToken
            if ($null -ne $headers) {
                $URI = $BaseURL + "/events/critical"
                try {
                    (Invoke-RestMethod -Method GET -Uri $URI -Headers $headers).criticalEventsInfoList
                } catch {
                    "An error was found with this command. Please review the resultant error for details."
                    $RESTError = Get-RestError($_)
                    "Errors: $RESTError"
                }
            }
        }
    }
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        if ($null -ne $headers) {
            $URI = $BaseURL + "/events/critical"
            try {
                if ($Global:SkipCert -eq $true) {
                    (Invoke-RestMethod -Method GET -Uri $URI -Headers $headers -SkipCertificateCheck).criticalEventsInfoList
                } else {
                    (Invoke-RestMethod -Method GET -Uri $URI -Headers $headers).criticalEventsInfoList
                }
            } catch {
                Get-RestErrorDetails
            }
        }
        if ($null -eq $headers) {
            Get-SEPToken
            if ($null -ne $headers) {
                $URI = $BaseURL + "/events/critical"
                try {
                    if ($Global:SkipCert -eq $true) {
                        (Invoke-RestMethod -Method GET -Uri $URI -Headers $headers -SkipCertificateCheck).criticalEventsInfoList
                    } else {
                        (Invoke-RestMethod -Method GET -Uri $URI -Headers $headers).criticalEventsInfoList
                    }
                } catch {
                    Get-RestErrorDetails
                }
            }
        }
    }
}