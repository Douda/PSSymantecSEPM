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
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPMIpsPolicy -PolicyName "Intrusion Prevention policy PRODUCTION"

        sources          : 
        configuration    : 
        enabled          : True
        desc             : IPS description field
        name             : Intrusion Prevention policy PRODUCTION
        lastmodifiedtime : 1693559858824

        Shows an example of getting the IPS policy details for the policy named "Intrusion Prevention policy PRODUCTION"
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
            Get-SEPMAccessToken | Out-Null
        }
        $URI = $script:BaseURLv1 + "/policies/ips"
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

        if ($policy_type -ne "ips") {
            $message = "policy type is not of type IPS or does not exist - Please verify the policy name"
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
    
        $resp = Invoke-ABRestMethod -params $params
        return $resp
    }
}