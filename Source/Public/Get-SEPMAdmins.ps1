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
        $URI = $session.BaseURLv1 + "/admin-users"

    }

    process {
        # URI query strings
        $QueryStrings = @{
            domain = $script:configuration.domain
        }

        # Construct the URI
        $URI = Build-SEPMQueryURI -BaseURI $URI -QueryStrings $QueryStrings

        $resp = Invoke-SepmApi -Method GET -Uri $URI -Session $session

        # Process the response
        if ([string]::IsNullOrEmpty($AdminName)) {
            return $resp
        } else {
            $resp = $resp | Where-Object { $_.loginName -eq $AdminName }
            return $resp
        }
    }
}
