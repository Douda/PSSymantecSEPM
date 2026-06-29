function Get-SEPMFirewallPolicy {
    <#
    .SYNOPSIS
        Get Firewall Policy
    .DESCRIPTION
        Get Firewall Policy details
    .PARAMETER PolicyName    
        The name of the policy to get the details of
        Is a required parameter
    .PARAMETER PolicyID
        The ID of the policy to get the details of
    .PARAMETER All
        Fetch all firewall policies.
    .PARAMETER PolicyList
        Optional array of policy summary objects to use when -All is specified.
        When provided, skips the internal Get-SEPMPoliciesSummary call and
        enumerates from this list instead. Ignored in the PolicyName and
        PolicyID parameter sets.
    .PARAMETER DelayMs
        Delay in milliseconds between individual policy fetches when -All is used. Default: 200.
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPMFirewallPolicy -PolicyName "Standard Servers - Firewall policy"

        sources          : 
        configuration    : @{enforced_rules=System.Object[]; baseline_rules=System.Object[]; ignore_parent_rules=; smart_dhcp=False; smart_dns=False; smart_wins=False; token_ring_traffic=False; netbios_protection=False; reverse_dns=False; port_scan=False;        
                            dos=False; antimac_spoofing=False; autoblock=False; autoblock_duration=600; stealth_web=False; antiIP_spoofing=False; hide_os=False; windows_firewall=NO_ACTION; windows_firewall_notification=False; endpoint_notification=; p2p_auth=;    
                            mac=}
        enabled          : True
        desc             : Standard Server Firewall Policy - This policy is for standard servers. It is a strict policy that blocks all traffic except for the services that are explicitly allowed.
        name             : Standard Servers - Firewall policy
        lastmodifiedtime : 1692253688318

        Shows an example of getting the firewall policy details for the policy named "Standard Servers - Firewall policy"
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPMFirewallPolicy -All

        Returns all firewall policies.
#>

    [CmdletBinding(DefaultParameterSetName = 'PolicyName')]
    Param (
        # PolicyName
        [Parameter(
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'PolicyName'
        )]
        [Alias("Policy_Name")]
        [String]
        $PolicyName,

        # Policy ID
        [Parameter(
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'PolicyID'
        )]
        [Alias("Policy_ID")]
        [String]
        $PolicyID,

        # All switch
        [Parameter(
            ParameterSetName = 'All'
        )]
        [switch]
        $All,

        # PolicyList (skip summary fetch when provided with -All)
        [Parameter(
            ParameterSetName = 'All'
        )]
        [object[]]
        $PolicyList,

        # DelayMs
        [Parameter(
            ParameterSetName = 'All'
        )]
        [int]
        $DelayMs = 200
    )

    begin {
        $session = Initialize-SEPMSession
        $endpoint = Get-SEPMApiEndpoint -OperationName 'Get-SEPMFirewallPolicy'
    }

    process {

        if ($All) {
            # Use provided policy list or fetch FW policy summaries
            if ($PSBoundParameters.ContainsKey('PolicyList')) {
                $fwPolicies = $PolicyList
            } else {
                $fwPolicies = Get-SEPMPoliciesSummary -PolicyType fw
            }
            $allResults = @()
            $total = $fwPolicies.Count
            $i = 0

            foreach ($fwPolicy in $fwPolicies) {
                $i++

                Write-Host "  -> FirewallPolicies ($i/$total): $($fwPolicy.name)" -ForegroundColor DarkGray

                $resp = Invoke-SepmEndpoint -Endpoint $endpoint -Session $session -PathIds @($fwPolicy.id)

                # Add a PSTypeName to the object
                $resp.PSObject.TypeNames.Insert(0, 'SEPM.FirewallPolicy')
                $allResults += $resp

                # Delay between API calls (skip after last)
                if ($i -lt $total) {
                    Start-Sleep -Milliseconds $DelayMs
                }
            }

            return $allResults
        }

        if ($PolicyName) {
            $policyID = Resolve-SEPMPolicy -PolicyName $PolicyName -PolicyType 'fw'
        }

        try {
            $resp = Invoke-SepmEndpoint -Endpoint $endpoint -Session $session -PathIds @($policyID)
        } catch {
            Write-Warning -Message "Error: $_"
        }

        # Add a PSTypeName to the object
        $resp.PSObject.TypeNames.Insert(0, 'SEPM.FirewallPolicy')
        
        return $resp
    }
}
