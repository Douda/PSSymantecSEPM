function Get-SEPMIpsPolicy {
    # TODO : returned object has empty configuration fields. Could be a bug ?
    # Example
    # PS C:\PSSymantecSEPM> $IPS_example | ConvertTo-Json
    # {
    #     "sources": null,
    #     "configuration": {},
    #     "enabled": true,
    #     "desc": "Summary : added IP as excluded host to avoid ServiceNow discovery service conflicts",
    #     "name": "Intrusion Prevention policy PRODUCTION",
    #     "lastmodifiedtime": 1693559858824
    # }

    <#
    .SYNOPSIS
        Get IPS Policy
    .DESCRIPTION
        Get IPS Policy details
    .PARAMETER PolicyName
        The name of the policy to get the details of.
        When provided, the function fetches policy summaries to resolve the name to an ID.
        Mutually exclusive with -PolicySummary.
    .PARAMETER PolicySummary
        A policy summary object (from Get-SEPMPoliciesSummary) for an IPS policy.
        When provided, skips the redundant summary fetch — the ID and type are extracted directly.
        Mutually exclusive with -PolicyName.
    .PARAMETER PolicyList
        Optional array of policy summary objects (from Get-SEPMPoliciesSummary).
        When provided with -PolicyName, skips the internal Get-SEPMPoliciesSummary
        call and resolves the policy ID from this list instead.
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPMIpsPolicy -PolicyName "Intrusion Prevention policy PRODUCTION"

        sources          : 
        configuration    : 
        enabled          : True
        desc             : IPS description field
        name             : Intrusion Prevention policy PRODUCTION
        lastmodifiedtime : 1693559858824

        Shows an example of getting the IPS policy details for the policy named "Intrusion Prevention policy PRODUCTION"
    .EXAMPLE
        PS C:\PSSymantecSEPM> $summaries = Get-SEPMPoliciesSummary
        PS C:\PSSymantecSEPM> $ipsSummary = $summaries | Where-Object { $_.policytype -eq 'ips' }
        PS C:\PSSymantecSEPM> Get-SEPMIpsPolicy -PolicySummary $ipsSummary

        Gets the IPS policy details using a pre-fetched summary, avoiding a redundant API call.
#>

    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    Param (
        # PolicyName
        [Parameter(
            ParameterSetName = 'ByName',
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [Alias("Policy_Name")]
        [String]
        $PolicyName,

        # PolicySummary
        [Parameter(
            ParameterSetName = 'BySummary',
            Mandatory = $true
        )]
        [PSCustomObject]
        $PolicySummary,

        # PolicyList
        [Parameter(
            ParameterSetName = 'ByName'
        )]
        [object[]]
        $PolicyList
    )

    begin {
        $session = Initialize-SEPMSession
        $endpoint = Get-SEPMApiEndpoint -OperationName 'Get-SEPMIpsPolicy'

        # Only fetch all summaries when resolving by name
        if ($PSCmdlet.ParameterSetName -eq 'ByName') {
            if ($PSBoundParameters.ContainsKey('PolicyList')) {
                $policies = $PolicyList
            } else {
                $policies = Get-SEPMPoliciesSummary
            }
        }
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'ByName') {
            # Get Policy ID from policy name
            $policy = $policies | Where-Object { $_.name -eq $PolicyName }
            $policyID = $policy.id
            $policy_type = $policy.policytype
        } else {
            # Extract directly from the pre-fetched summary
            $policyID = $PolicySummary.id
            $policy_type = $PolicySummary.policytype
        }

        if ($policy_type -ne "ips") {
            $message = "policy type is not of type IPS or does not exist - Please verify the policy name"
            Write-Error -Message $message
            throw $message
        }

        $resp = Invoke-SepmEndpoint -Endpoint $endpoint -Session $session -PathIds @($policyID)
        return $resp
    }
}
