Function Get-SEPClientVersions {
    if ($PSVersionTable.PSVersion.Major -lt 6) {
        if ($null -ne $headers) {
            $URI = $BaseURL + "/stats/client/version"
            try {
                (Invoke-RestMethod -Method GET -Uri $URI -Headers $headers).clientVersionList
            } catch {
                "An error was found with this command. Please review the resultant error for details."
                $RESTError = Get-RestError($_)
                "Errors: $RESTError"
            }
        }
        if ($null -eq $headers) {
            Get-SEPToken
            if ($null -ne $headers) {
                $URI = $BaseURL + "/stats/client/version"
                try {
                    (Invoke-RestMethod -Method GET -Uri $URI -Headers $headers).clientVersionList
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
            $URI = $BaseURL + "/stats/client/version"
            try {
                if ($Global:SkipCert -eq $true) {
                    (Invoke-RestMethod -Method GET -Uri $URI -Headers $headers -SkipCertificateCheck).clientVersionList
                } else {
                    (Invoke-RestMethod -Method GET -Uri $URI -Headers $headers).clientVersionList
                }
            } catch {
                Get-RestErrorDetails
            }
        }
        if ($null -eq $headers) {
            Get-SEPToken
            if ($null -ne $headers) {
                $URI = $BaseURL + "/stats/client/version"
                try {
                    if ($Global:SkipCert -eq $true) {
                        (Invoke-RestMethod -Method GET -Uri $URI -Headers $headers -SkipCertificateCheck).clientVersionList
                    } else {
                        (Invoke-RestMethod -Method GET -Uri $URI -Headers $headers).clientVersionList
                    }
                } catch {
                    Get-RestErrorDetails
                }
            }
        }
    }
}