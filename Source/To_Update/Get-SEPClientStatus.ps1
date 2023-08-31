Function Get-SEPClientStatus {
    if ($PSVersionTable.PSVersion.Major -lt 6) {
        if ($null -ne $headers) {
            $URI = $BaseURL + "/stats/client/onlinestatus"
            try {
                (Invoke-RestMethod -Method GET -Uri $URI -Headers $headers).clientCountStatsList
            } catch {
                "An error was found with this command. Please review the resultant error for details."
                $RESTError = Get-RestError($_)
                "Errors: $RESTError"
            }
        }
        if ($null -eq $headers) {
            Get-SEPToken
            if ($null -ne $headers) {
                $URI = $BaseURL + "/stats/client/onlinestatus"
                try {
                    (Invoke-RestMethod -Method GET -Uri $URI -Headers $headers).clientCountStatsList
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
            $URI = $BaseURL + "/stats/client/onlinestatus"
            try {
                if ($Global:SkipCert -eq $true) {
                    (Invoke-RestMethod -Method GET -Uri $URI -Headers $headers -SkipCertificateCheck).clientCountStatsList
                } else {
                    (Invoke-RestMethod -Method GET -Uri $URI -Headers $headers).clientCountStatsList
                }
            } catch {
                "An error was found with this command. Please review the resultant error for details."
                $RESTError = Get-RestError($_)
                "Errors: $RESTError"
            }
        }
        if ($null -eq $headers) {
            Get-SEPToken
            if ($null -ne $headers) {
                $URI = $BaseURL + "/stats/client/onlinestatus"
                try {
                    if ($Global:SkipCert -eq $true) {
                        (Invoke-RestMethod -Method GET -Uri $URI -Headers $headers -SkipCertificateCheck).clientCountStatsList
                    } else {
                        (Invoke-RestMethod -Method GET -Uri $URI -Headers $headers).clientCountStatsList
                    }
                } catch {
                    Get-RestErrorDetails
                }
            }
        }  
    }
}