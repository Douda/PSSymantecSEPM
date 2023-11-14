function Get-SEPClientInfectedStatus {
    <# 
    .SYNOPSIS
        Gets SEP Clients with Infected or Clean status
    .DESCRIPTION
        Gets SEP Clients with Infected or Clean status
        NOTES : Clean status is just Infected = 0

    .INPUTS
        None
    .OUTPUTS
        List of SEP Clients with Infected status
    .PARAMETER Clean
        If specified, returns SEP Clients with Clean status
    .PARAMETER SkipCertificateCheck
        Skip certificate check
    .EXAMPLE
        Get-SEPClientInfectedStatus

        Gets computer details for all computers in the domain
    .EXAMPLE
        Get-SEPClientInfectedStatus -Clean

        Gets computer details for all computers in the domain that are not infected
#>

    [CmdletBinding()]
    param (
        [Parameter()]
        [switch]
        $Clean,

        # Skip certificate check
        [Parameter()]
        [switch]
        $SkipCertificateCheck
    )

    begin {
        if ($SkipCertificateCheck) {
            $script:SkipCert = $true
        }
    }

    process {
        if ($clean) {
            $non_infected = Get-SEPComputers | Where-Object { $_.infected -ne 1 }
            return $non_infected
        } else {
            $infected = Get-SEPComputers | Where-Object { $_.infected -eq 1 }
            return $Infected
        }
    }
}