function Set-SEPQuarantine {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][String]$ComputerName,
        [Parameter(Mandatory)][ValidateSet('true', 'false')][String[]]$Disabled
    )
    $ComputerID = (Get-SEPComputers -ComputerName $ComputerName).uniqueId
    $URI = $BaseURL + ("/command-queue/quarantine") + "?computer_ids=" + $ComputerID + "&undo=" + $Disabled
    if ($PSVersionTable.PSVersion.Major -lt 6) {
        try {
            $Result = (Invoke-RestMethod -Method POST -Uri $URI -Headers $headers)
            if ($null -ne $Result) {
                "Quarantine Disabled: $Disabled, was successfully set for: $ComputerName"
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
                    "Quarantine Disabled: $Disabled, was successfully set for: $ComputerName"
                    $Result
                }
            } else {
                $Result = (Invoke-RestMethod -Method POST -Uri $URI -Headers $headers)
                if ($null -ne $Result) {
                    "Quarantine Disabled: $Disabled, was successfully set for: $ComputerName"
                    $Result
                }
            }
        } catch {
            Get-RestErrorDetails
        }
    }
}