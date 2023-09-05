Function Get-SEPMFirewallPolicies {
    if ($PSVersionTable.PSVersion.Major -lt 6) {
        if ($null -ne $headers) {
            $URI = $BaseURL + "/policies/summary/fw"
            try {
                (Invoke-RestMethod -Method GET -Uri $URI -Headers $headers).content
            } catch {
                "An error was found with this command. Please review the resultant error for details."
                $RESTError = Get-RestError($_)
                "Errors: $RESTError"
            }
        }
        if ($null -eq $headers) {
            Get-SEPToken
            if ($null -ne $headers) {
                $URI = $BaseURL + "/policies/summary/fw"
                try {
                    (Invoke-RestMethod -Method GET -Uri $URI -Headers $headers).content
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
            $URI = $BaseURL + "/policies/summary/fw"
            try {
                if ($Global:SkipCert -eq $true) {
                    (Invoke-RestMethod -Method GET -Uri $URI -Headers $headers -SkipCertificateCheck).content
                } else {
                    (Invoke-RestMethod -Method GET -Uri $URI -Headers $headers).content
                }
            } catch {
                Get-RestErrorDetails
            }
        }
        if ($null -eq $headers) {
            Get-SEPToken
            if ($null -ne $headers) {
                $URI = $BaseURL + "/policies/summary/fw"
                try {
                    if ($Global:SkipCert -eq $true) {
                        (Invoke-RestMethod -Method GET -Uri $URI -Headers $headers -SkipCertificateCheck).content
                    } else {
                        (Invoke-RestMethod -Method GET -Uri $URI -Headers $headers).content
                    }
                } catch {
                    Get-RestErrorDetails
                }
            }
        }
    }
}