function Get-SEPMFirewallPolicy {
    <#
    .SYNOPSIS
        Get Firewall Policy
    .DESCRIPTION
        Get Firewall Policy details
    .PARAMETER PolicyName    
        The name of the policy to get the details of
        Is a required parameter
    .PARAMETER SkipCertificateCheck
        Skip certificate check
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
        $URI = $script:BaseURLv1 + "/policies/firewall"
        $headers = @{
            "Authorization" = "Bearer " + $script:accessToken.token
            "Content"       = 'application/json'
        }
        
    }

    process {

        if ($PolicyName) {
            # Get Policy ID from policy name
            $policies = Get-SEPMPoliciesSummary
            $policyID = $policies | Where-Object { $_.name -eq $PolicyName } | Select-Object -ExpandProperty id
            $policy_type = $policies | Where-Object { $_.name -eq $PolicyName } | Select-Object -ExpandProperty policytype

            if ($policy_type -ne "fw") {
                $message = "policy type is not of type FIREWALL or does not exist - Please verify the policy name"
                Write-Error -Message $message
                throw $message
            }
        }

        # Updating URI with policy ID
        $URI = $URI + "/" + $policyID
        
        # prepare the parameters
        $params = @{
            Method  = 'GET'
            Uri     = $URI
            headers = $headers
        }

        try {
            $resp = Invoke-ABRestMethod -params $params
        } catch {
            Write-Warning -Message "Error: $_"
        }

        # Add a PSTypeName to the object
        $resp.PSObject.TypeNames.Insert(0, 'SEPM.FirewallPolicy')
        
        return $resp
    }
}