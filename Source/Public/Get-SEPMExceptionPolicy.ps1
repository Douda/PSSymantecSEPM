function Get-SEPMExceptionPolicy {
    <#
    .SYNOPSIS
        Get Exception Policy
    .DESCRIPTION
        Get Exception Policy details
        Note this is a V2 API call, and replies are originally JSON based
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPMExceptionPolicy -PolicyName "Standard Servers - Exception policy"

        Name                           Value
        ----                           -----
        sources                        {}
        configuration                  {[files, System.Object[]], [non_pe_rules, System.Object[]], [directories, System.Object[]], [webdomains, System.Object[]]…}
        lockedoptions                  {[knownrisk, True], [extension, True], [file, True], [domain, True]…}
        enabled                        True
        desc
        name                           Standard Servers - Exception policy
        lastmodifiedtime               1646398353107

        Shows an example of getting the Exception policy details for the policy named "Standard Servers - Exception policy"
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
        if (-not $test_token){
            Get-SEPMAccessToken | Out-Null
        }
        # BaseURL V2
        $URI = $script:BaseURLv2 + "/policies/exceptions"
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
        
        # prepare the parameters
        $params = @{
            Method          = 'GET'
            Uri             = $URI
            headers         = $headers
            UseBasicParsing = $true
        }
    
        $resp = Invoke-ABRestMethod -params $params

        # JSON response to convert to PSObject
        $resp = $resp | ConvertFrom-Json -AsHashtable -Depth 100
        
        # return the response
        return $resp
    }
}