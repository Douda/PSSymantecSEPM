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

    [CmdletBinding()]
    param()

    begin {
        $session = Initialize-SEPMSession
        $URI = $session.BaseURLv1 + "/replication/status"

    }

    process {
        # prepare the parameters
        $params = @{
            Session = $session
            Method  = 'GET'
            Uri     = $URI
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
