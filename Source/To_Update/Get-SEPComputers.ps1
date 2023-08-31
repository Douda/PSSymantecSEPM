Function Get-SEPComputers {
    <#
    .SYNOPSIS
    Displays a short or specific list of computers and their information from the Symantec Database
 
    .PARAMETER ComputerName
    Specifies the computer to return information on from the Symantec Database
 
    .EXAMPLE
    Get-SEPComputers -ComputerName TESTPC OR
    Get-SEPComputers
    #>
    [CmdletBinding()]
    Param (
        [Parameter()][ValidateNotNullOrEmpty()][String]$ComputerName
    )
    if ($PSVersionTable.PSVersion.Major -lt 6) {
        if ($null -ne $headers) {
            if ($null -ne $ComputerName) {
                $URI = $BaseURL + "/computers?computerName=$ComputerName"
                try {
                    (Invoke-RestMethod -Method GET -Uri $URI -Headers $headers).content
                } catch {
                    "An error was found with this command. Please review the resultant error for details."
                    $RESTError = Get-RestError($_)
                    "Errors: $RESTError"
                }
            } else {
                $URI = $BaseURL + '/computers'
                try {
                    (Invoke-RestMethod -Method GET -Uri $URI -Headers $headers).content
                } catch {
                    "An error was found with this command. Please review the resultant error for details."
                    $RESTError = Get-RestError($_)
                    "Errors: $RESTError"
                }
            }
        }
        if ($null -eq $headers) {
            Get-SEPToken
            if ($null -ne $headers) {
                if ($null -ne $ComputerName) {
                    $URI = $BaseURL + "/computers?computerName=$ComputerName"
                    try {
                        (Invoke-RestMethod -Method GET -Uri $URI -Headers $headers).content
                    } catch {
                        "An error was found with this command. Please review the resultant error for details."
                        $RESTError = Get-RestError($_)
                        "Errors: $RESTError"
                    }
                } else {
                    $URI = $BaseURL + '/computers'
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
    }
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        if ($null -ne $headers) {
            if ($null -ne $ComputerName) {
                $URI = $BaseURL + "/computers?computerName=$ComputerName"
                try {
                    if ($Global:SkipCert -eq $true) {
                        (Invoke-RestMethod -Method GET -Uri $URI -Headers $headers -SkipCertificateCheck).content
                    } else {
                        (Invoke-RestMethod -Method GET -Uri $URI -Headers $headers).content
                    }
                } catch {
                    Get-RestErrorDetails
                }
            } else {
                $URI = $BaseURL + '/computers'
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
        if ($null -eq $headers) {
            Get-SEPToken
            if ($null -ne $headers) {
                if ($null -ne $ComputerName) {
                    $URI = $BaseURL + "/computers?computerName=$ComputerName"
                    try {
                        if ($Global:SkipCert -eq $true) {
                            (Invoke-RestMethod -Method GET -Uri $URI -Headers $headers -SkipCertificateCheck).content
                        } else {
                            (Invoke-RestMethod -Method GET -Uri $URI -Headers $headers).content
                        }
                    } catch {
                        Get-RestErrorDetails
                    }
                } else {
                    $URI = $BaseURL + '/computers'
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
}