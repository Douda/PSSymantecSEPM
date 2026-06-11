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
        $endpoint = Get-SEPMApiEndpoint -OperationName 'Get-SEPMReplicationStatus'
    }

    process {
        $resp = Invoke-SepmEndpoint -Endpoint $endpoint -Session $session

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

        Write-Output $resp.replicationStatus -NoEnumerate
    }
}
