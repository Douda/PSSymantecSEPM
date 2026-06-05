Function Get-SEPMAdmins {
    <#
    .SYNOPSIS
        Displays a list of admins in the Symantec Database

    .DESCRIPTION
        Gets the list of administrators for a particular domain.

        The Git repo for this module can be found here: https://github.com/Douda/PSSymantecSEPM

    .PARAMETER AdminName
        Displays only a specific user from the Admin List

    .PARAMETER SkipCertificateCheck
        Skip certificate check

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
        $AdminName,

        # Skip certificate check
        [Parameter()]
        [switch]
        $SkipCertificateCheck
    )

    begin {
        $session = Initialize-SEPMSession -SkipCertificateCheck:$SkipCertificateCheck
        $URI = $session.BaseURLv1 + "/admin-users"
    }

    process {
        # URI query strings
        $QueryStrings = @{
            domain = $script:configuration.domain
        }

        # Construct the URI
        $URI = Build-SEPMQueryURI -BaseURI $URI -QueryStrings $QueryStrings

        $params = @{
            Method  = 'GET'
            Uri     = $URI
            headers = $session.Headers
        }
        
        $resp = Invoke-ABRestMethod -params $params

        
        # Add a PSTypeName to the object
        $resp | ForEach-Object {
            $_.PSTypeNames.Insert(0, "SEP.adminList")
        }

        # Process the response
        if ([string]::IsNullOrEmpty($AdminName)) {
            return $resp
        } else {
            $resp = $resp | Where-Object { $_.loginName -eq $AdminName }
            return $resp
        }
    }
}