function Get-SEPMExceptionPolicy {
    <#
    .SYNOPSIS
        Get Firewall Policy
    .DESCRIPTION
        Get Firewall Policy details
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPMExceptionPolicy -PolicyName "Standard Servers - Firewall policy"

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

    [CmdletBinding()]
    Param (
        # PolicyName
        [Parameter(
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [Alias("Policy_Name")]
        [String]
        $PolicyName
    )

    begin {
        # initialize the configuration
        $test_token = Test-SEPMAccessToken
        if ($test_token -eq $false) {
            Get-SEPMAccessToken
        }
        $URI = $script:BaseURLv1 + "/policies/exceptions"
        $headers = @{
            "Authorization" = "Bearer " + $script:accessToken.token
            "Content"       = 'application/json'
        }
        # Stores the policy summary for all policies only once
        $policies = Get-SEPMPoliciesSummary
    }

    process {
        # Get Policy ID from policy name
        $policyID = $policies | Where-Object { $_.name -eq $PolicyName } | Select-Object -ExpandProperty id
        $policy_type = $policies | Where-Object { $_.name -eq $PolicyName } | Select-Object -ExpandProperty policytype

        if ($policy_type -ne "exceptions") {
            $message = "policy type is not of type EXCEPTIONS or does not exist - Please verify the policy name"
            Write-Error -Message $message
            throw $message
        }

        # Updating URI with policy ID
        $URI = $URI + "/" + $policyID
        
        # URI query strings
        $QueryStrings = @{}

        # Construct the URI
        $builder = New-Object System.UriBuilder($URI)
        $query = [System.Web.HttpUtility]::ParseQueryString($builder.Query)
        foreach ($param in $QueryStrings.GetEnumerator()) {
            $query[$param.Key] = $param.Value
        }
        $builder.Query = $query.ToString()
        $URI = $builder.ToString()

        $params = @{
            Method          = 'GET'
            Uri             = $URI
            headers         = $headers
            UseBasicParsing = $true
        }
    
        # Invoke the request
        # If the version of PowerShell is 6 or greater, then we can use the -SkipCertificateCheck parameter
        # else we need to use the Skip-Cert function if self-signed certs are being used.
        switch ($PSVersionTable.PSVersion.Major) {
            { $_ -ge 6 } { 
                try {
                    if ($script:accessToken.skipCert -eq $true) {
                        $resp = Invoke-RestMethod @params -SkipCertificateCheck
                    } else {
                        $resp = Invoke-RestMethod @params
                    }
                } catch {
                    Write-Warning -Message "Error: $_"
                }
            }
            default {
                try {
                    if ($script:accessToken.skipCert -eq $true) {
                        Skip-Cert
                        $resp = Invoke-RestMethod @params
                    } else {
                        $resp = Invoke-RestMethod @params
                    }
                } catch {
                    Write-Warning -Message "Error: $_"
                }
            }
        }

        # return the response
        return $resp
    }
}