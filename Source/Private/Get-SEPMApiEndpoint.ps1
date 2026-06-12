# The declarative endpoint registry maps each exported cmdlet name to its
# API contract (version, HTTP method, path). Initialized once at module
# import. See docs/adr/0008-endpoint-registry.md.
if (-not $script:_endpointRegistry) {
    $script:_endpointRegistry = @{
        'Get-SEPMVersion' = @{
            OperationName = 'Get-SEPMVersion'
            Version       = '1.0'
            Method        = 'GET'
            Path          = '/version'
        }
        'Get-SEPMAdmins' = @{
            OperationName = 'Get-SEPMAdmins'
            Version       = '1.0'
            Method        = 'GET'
            Path          = '/admin-users'
            QueryParams   = @{ domain = 'Domain' }
        }
        'Get-SEPMDomain' = @{
            OperationName = 'Get-SEPMDomain'
            Version       = '1.0'
            Method        = 'GET'
            Path          = '/domains'
        }
        'Get-SEPClientStatus' = @{
            OperationName = 'Get-SEPClientStatus'
            Version       = '1.0'
            Method        = 'GET'
            Path          = '/stats/client/onlinestatus'
        }
        'Get-SEPClientVersion' = @{
            OperationName = 'Get-SEPClientVersion'
            Version       = '1.0'
            Method        = 'GET'
            Path          = '/stats/client/version'
        }
        'Get-SEPClientDefVersions' = @{
            OperationName = 'Get-SEPClientDefVersions'
            Version       = '1.0'
            Method        = 'GET'
            Path          = '/stats/client/content'
        }
        'Get-SEPGUPList' = @{
            OperationName = 'Get-SEPGUPList'
            Version       = '1.0'
            Method        = 'GET'
            Path          = '/gup/status'
        }
        'Get-SEPMReplicationStatus' = @{
            OperationName = 'Get-SEPMReplicationStatus'
            Version       = '1.0'
            Method        = 'GET'
            Path          = '/replication/status'
        }
        'Get-SEPMThreatStats' = @{
            OperationName = 'Get-SEPMThreatStats'
            Version       = '1.0'
            Method        = 'GET'
            Path          = '/stats/threat'
        }
        'Get-SEPMDatabaseInfo' = @{
            OperationName = 'Get-SEPMDatabaseInfo'
            Version       = '1.0'
            Method        = 'GET'
            Path          = '/admin/database'
        }
        'Get-SEPMLatestDefinition' = @{
            OperationName = 'Get-SEPMLatestDefinition'
            Version       = '1.0'
            Method        = 'GET'
            Path          = '/content/avdef/latest'
        }
        'Get-SEPMLicense' = @{
            OperationName = 'Get-SEPMLicense'
            Version       = '1.0'
            Method        = 'GET'
            Path          = '/licenses'
        }
        'Get-SEPMLicenseSummary' = @{
            OperationName = 'Get-SEPMLicenseSummary'
            Version       = '1.0'
            Method        = 'GET'
            Path          = '/licenses/summary'
        }
        'Get-SEPMEventInfo' = @{
            OperationName = 'Get-SEPMEventInfo'
            Version       = '1.0'
            Method        = 'GET'
            Path          = '/events/critical'
        }
        'Get-SEPMExceptionPolicy' = @{
            OperationName = 'Get-SEPMExceptionPolicy'
            Version       = '2.0'
            Method        = 'GET'
            Path          = '/policies/exceptions/{id}'
        }
        'Get-SEPMFirewallPolicy' = @{
            OperationName = 'Get-SEPMFirewallPolicy'
            Version       = '1.0'
            Method        = 'GET'
            Path          = '/policies/firewall/{id}'
        }
        'Get-SEPMIpsPolicy' = @{
            OperationName = 'Get-SEPMIpsPolicy'
            Version       = '1.0'
            Method        = 'GET'
            Path          = '/policies/ips/{id}'
        }
        'Get-SEPMGroupSettings' = @{
            OperationName = 'Get-SEPMGroupSettings'
            Version       = '1.0'
            Method        = 'GET'
            Path          = '/groups/{id}/locations/{id}/settings'
        }
        'Get-SEPMPolicyXML' = @{
            OperationName = 'Get-SEPMPolicyXML'
            Version       = '1.0'
            Method        = 'GET'
            Path          = '/policies/raw/{id}/{id}'
        }
        'Get-SEPMLocationXML' = @{
            OperationName = 'Get-SEPMLocationXML'
            Version       = '1.0'
            Method        = 'GET'
            Path          = '/groups/{id}/locations/{id}/xml'
        }
        'New-SEPMGroup' = @{
            OperationName = 'New-SEPMGroup'
            Version       = '1.0'
            Method        = 'POST'
            Path          = '/groups/{id}'
            BodyParams    = @{
                name        = 'GroupName'
                description = 'Description'
                inherits    = 'EnabledInheritance'
            }
        }
        'Remove-SEPMGroup' = @{
            OperationName = 'Remove-SEPMGroup'
            Version       = '1.0'
            Method        = 'DELETE'
            Path          = '/groups/{id}'
        }
        'Add-SEPMFileFingerprintList' = @{
            OperationName = 'Add-SEPMFileFingerprintList'
            Version       = '1.0'
            Method        = 'POST'
            Path          = '/policy-objects/fingerprints'
            BodyParams    = @{
                name        = 'name'
                domainId    = 'domainId'
                hashType    = 'HashType'
                description = 'description'
                data        = 'hashlist'
            }
        }
        'Remove-SEPMFileFingerprintList' = @{
            OperationName = 'Remove-SEPMFileFingerprintList'
            Version       = '1.0'
            Method        = 'DELETE'
            Path          = '/policy-objects/fingerprints/{id}'
        }
        'Update-SEPMFileFingerprintList' = @{
            OperationName = 'Update-SEPMFileFingerprintList'
            Version       = '1.0'
            Method        = 'POST'
            Path          = '/policy-objects/fingerprints/{id}'
            BodyParams    = @{
                name        = 'name'
                domainId    = 'domainId'
                hashType    = 'HashType'
                description = 'description'
                data        = 'hashlist'
            }
        }
        'Start-SEPMReplication' = @{
            OperationName = 'Start-SEPMReplication'
            Version       = '1.0'
            Method        = 'POST'
            Path          = '/replication/replicatenow'
            QueryParams   = @{ partnerSiteName = 'partnerSiteName' }
        }
        'Move-SEPClientGroup' = @{
            OperationName = 'Move-SEPClientGroup'
            Version       = '1.0'
            Method        = 'PATCH'
            Path          = '/computers'
        }
        'Get-SEPComputers' = @{
            OperationName = 'Get-SEPComputers'
            Version       = '1.0'
            Method        = 'GET'
            Path          = '/computers'
            QueryParams   = @{
                computerName = 'ComputerName'
            }
            Paginated     = $true
            PageDefaults  = @{ sort = 'COMPUTER_NAME'; pageSize = 100 }
        }
        'Get-SEPMGroups' = @{
            OperationName = 'Get-SEPMGroups'
            Version       = '1.0'
            Method        = 'GET'
            Path          = '/groups'
            Paginated     = $true
            PageDefaults  = @{ pageSize = 25 }
        }
        'Get-SEPMCommandStatus' = @{
            OperationName = 'Get-SEPMCommandStatus'
            Version       = '1.0'
            Method        = 'GET'
            Path          = '/command-queue/{id}'
            Paginated     = $true
            PageDefaults  = @{}
        }
        'Get-SEPMLocation' = @{
            OperationName = 'Get-SEPMLocation'
            Version       = '1.0'
            Method        = 'GET'
            Path          = '/groups/{id}/locations'
        }
        'Get-SEPMPolicySnapshot' = @{
            OperationName = 'Get-SEPMPolicySnapshot'
            Version       = '1.0'
            Method        = 'GET'
            Path          = '/groups/{id}/locations'
        }
        'Get-SEPMFileFingerprintList' = @{
            OperationName = 'Get-SEPMFileFingerprintList'
            Version       = '1.0'
            Method        = 'GET'
            Path          = '/policy-objects/fingerprints'
            QueryParams   = @{
                name = 'FingerprintListName'
            }
        }
        'Get-SEPFileDetails' = @{
            OperationName = 'Get-SEPFileDetails'
            Version       = '1.0'
            Method        = 'GET'
            Path          = '/command-queue/file/{id}/details'
            QueryParams   = @{
                file_id = 'FileID'
            }
        }
        'Send-SEPMCommand' = @{
            OperationName = 'Send-SEPMCommand'
            Version       = '1.0'
            Method        = 'POST'
            Path          = '/command-queue/{id}'
        }
        'Confirm-SEPMEventInfo' = @{
            OperationName = 'Confirm-SEPMEventInfo'
            Version       = '1.0'
            Method        = 'POST'
            Path          = '/events/acknowledge/{id}'
        }
        'Get-SEPMPoliciesSummary' = @{
            OperationName = 'Get-SEPMPoliciesSummary'
            Version       = '1.0'
            Method        = 'GET'
            Path          = '/policies/summary'
        }
        'Update-SEPMExceptionPolicy' = @{
            OperationName = 'Update-SEPMExceptionPolicy'
            Version       = '2.0'
            Method        = 'PATCH'
            Path          = '/policies/exceptions/{id}'
        }
    }
}

function Get-SEPMApiEndpoint {
    <#
    .SYNOPSIS
        Returns the registry entry for a given SEPM API operation.

    .DESCRIPTION
        Looks up the declarative endpoint registry and returns the entry (Version, Method,
        Path, etc.) for the specified operation name. The registry defines every SEPM API
        call the module supports.

    .PARAMETER OperationName
        The name of the exported cmdlet (e.g. 'Get-SEPMVersion').

    .OUTPUTS
        System.Collections.Hashtable with keys: OperationName, Version, Method, Path.

    .NOTES
        Internal helper method. Not exported.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OperationName
    )

    if (-not $script:_endpointRegistry.ContainsKey($OperationName)) {
        throw "No endpoint registered for operation '$OperationName'."
    }

    return $script:_endpointRegistry[$OperationName]
}
