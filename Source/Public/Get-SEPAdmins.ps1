Function Get-SEPAdmins {
    <#
.SYNOPSIS
Displays a list of admins in the Symantec Database
.EXAMPLE
Get-SEPAdmins
 
.PARAMETER AdminName
Displays only a specific user from the Admin List
Get-SEPAdmins -AdminName admin
 
.EXAMPLE
Get-SEPAdmins
 
.NOTES
General notes
#>
    [CmdletBinding()]
    Param (
        # AdminName
        [Parameter()]
        [String]
        $AdminName
    )
    # 
    if ($PSVersionTable.PSVersion.Major -lt 6) {
        if ($null -ne $headers) {
            $URI = $BaseURL + "/admin-users"
            try {
                $admins = (Invoke-RestMethod -Method GET -Uri $URI -Headers $headers)
                if ($AdminName -eq "") {
                    $admins
                }
                if ("" -ne $AdminName) {
                    $admins  | Where-Object { $_.loginName -eq $AdminName }
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
                $URI = $BaseURL + "/admin-users"
                try {
                    $admins = (Invoke-RestMethod -Method GET -Uri $URI -Headers $headers)
                    if ($AdminName -eq "") {
                        $admins
                    }
                    if ("" -ne $AdminName) {
                        $admins  | Where-Object { $_.loginName -eq $AdminName }
                    }
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
            $URI = $BaseURL + "/admin-users"
            try {
                if ($Global:SkipCert -eq $true) {
                    $admins = (Invoke-RestMethod -Method GET -Uri $URI -Headers $headers -SkipCertificateCheck)
                    if ($AdminName -eq "") {
                        $admins
                    }
                    if ("" -ne $AdminName) {
                        $admins  | Where-Object { $_.loginName -eq $AdminName }
                    }
                } else {
                    $admins = (Invoke-RestMethod -Method GET -Uri $URI -Headers $headers)
                    if ($AdminName -eq "") {
                        $admins
                    }
                    if ("" -ne $AdminName) {
                        $admins  | Where-Object { $_.loginName -eq $AdminName }
                    } 
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
                $URI = $BaseURL + "/admin-users"
                try {
                    if ($Global:SkipCert -eq $true) {
                        $admins = (Invoke-RestMethod -Method GET -Uri $URI -Headers $headers -SkipCertificateCheck)
                        if ($AdminName -eq "") {
                            $admins
                        }
                        if ("" -ne $AdminName) {
                            $admins  | Where-Object { $_.loginName -eq $AdminName }
                        }
                    } else {
                        $admins = (Invoke-RestMethod -Method GET -Uri $URI -Headers $headers)
                        if ($AdminName -eq "") {
                            $admins
                        }
                        if ("" -ne $AdminName) {
                            $admins  | Where-Object { $_.loginName -eq $AdminName }
                        } 
                    }
                } catch {
                    Get-RestErrorDetails
                }
            }
        }
    }
}