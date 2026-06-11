Function Get-SEPMAdmins {
    <#
    .SYNOPSIS
        Displays a list of admins in the Symantec Database

    .DESCRIPTION
        Gets the list of administrators for a particular domain.

        The Git repo for this module can be found here: https://github.com/Douda/PSSymantecSEPM

    .PARAMETER AdminName
        Displays only a specific user from the Admin List

    .EXAMPLE
        Get-SEPMAdmins
    
    .EXAMPLE
    Get-SEPMAdmins -AdminName admin

#>
    [CmdletBinding()]
    Param (
        # AdminName
        [Parameter(
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [String]
        [Alias("Admin")]
        $AdminName
    )

    begin {
        $session = Initialize-SEPMSession
        $endpoint = Get-SEPMApiEndpoint -OperationName 'Get-SEPMAdmins'
    }

    process {
        # Domain comes from module-scoped configuration, not a cmdlet parameter
        $extraParams = @{ domain = $script:configuration.domain }

        $resp = Invoke-SepmEndpoint -Endpoint $endpoint -Session $session -AdditionalQueryParams $extraParams

        # Process the response
        if ([string]::IsNullOrEmpty($AdminName)) {
            return $resp
        } else {
            $resp = $resp | Where-Object { $_.loginName -eq $AdminName }
            return $resp
        }
    }
}
