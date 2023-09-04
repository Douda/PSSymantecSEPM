function Start-SEPScan {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][String]$ComputerName,
        [Parameter(Mandatory)][ValidateSet('fullscan', 'activescan')][String[]]$ScanType
    )
    $ComputerID = (Get-SEPComputers -ComputerName $ComputerName).uniqueId
    $URI = $BaseURL + ("/command-queue/") + [string]$ScanType + "?computer_ids=" + $ComputerID
    if ($PSVersionTable.PSVersion.Major -lt 6) {
        try {
            $Result = (Invoke-RestMethod -Method POST -Uri $URI -Headers $headers)
            if ($null -ne $Result) {
                "Scan Type: $ScanType, was successfully sent for: $ComputerName"
                $Result
            }
        } catch {
            "An error was found with this command. Please review the resultant error for details."
            $RESTError = Get-RestError($_)
            "Errors: $RESTError"
        }
    }
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        try {
            if ($Global:SkipCert -eq $true) {
                $Result = (Invoke-RestMethod -Method POST -Uri $URI -Headers $headers -SkipCertificateCheck)
                if ($null -ne $Result) {
                    "Scan Type: $ScanType, was successfully sent for: $ComputerName"
                    $Result
                }
            } else {
                $Result = (Invoke-RestMethod -Method POST -Uri $URI -Headers $headers)
                if ($null -ne $Result) {
                    "Scan Type: $ScanType, was successfully sent for: $ComputerName"
                    $Result
                }
            }
        } catch {
            Get-RestErrorDetails
        }
    }
}