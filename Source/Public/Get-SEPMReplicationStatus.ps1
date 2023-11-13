function Get-SEPMReplicationStatus {
    <# 
    .SYNOPSIS
        Get Replication Status
    .DESCRIPTION
        Get Replication Status
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPMReplicationStatus

        replicationStatus
        -----------------
        @{siteName=Site Europe; siteLocation=Paris; replicationPartnerStatusList=System.Object[]; id=XXXXXXXXXXXXXXXXXXXXXXXX}

        Get a list of replication status with every remote site
#>

    begin {
        # initialize the configuration
        $test_token = Test-SEPMAccessToken
        if (-not $test_token) {
            Get-SEPMAccessToken | Out-Null
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
        return $resp
    }
}