function Get-SEPMReplicationStatus {
    <# 
    .SYNOPSIS
        Get Replication Status
    .DESCRIPTION
        Get Replication Status
    .PARAMETER SkipCertificateCheck
        Skip certificate check
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPMReplicationStatus

        replicationStatus
        -----------------
        @{siteName=Site Europe; siteLocation=Paris; replicationPartnerStatusList=System.Object[]; id=XXXXXXXXXXXXXXXXXXXXXXXX}

        Get a list of replication status with every remote site
#>

    [CmdletBinding()]
    param (
        # Skip certificate check
        [Parameter()]
        [switch]
        $SkipCertificateCheck
    )

    begin {
        # initialize the configuration
        $test_token = Test-SEPMAccessToken
        if (-not $test_token) {
            Get-SEPMAccessToken | Out-Null
        }
        if ($SkipCertificateCheck) {
            $script:SkipCert = $true
        }
        $URI = $script:BaseURLv1 + "/replication/status"
        $headers = @{
            "Authorization" = "Bearer " + $script:accessToken.token
            "Content"       = 'application/json'
        }
    }

    process {
        # prepare the parameters
        $params = @{
            Method  = 'GET'
            Uri     = $URI
            headers = $headers
        }
    
        $resp = Invoke-ABRestMethod -params $params

        # Add a PSTypeName to the object
        $resp.replicationStatus | ForEach-Object {
            $_.PSObject.TypeNames.Insert(0, 'SEPM.ReplicationStatus')
            # Add sub PSTypeName to the object
            foreach ($partner in $_.replicationPartnerStatusList) {
                $partner | ForEach-Object {
                    $_.PSObject.TypeNames.Insert(0, 'SEPM.ReplicationPartnerStatus')
                }
            }
        }

        return $resp.replicationStatus
    }
}