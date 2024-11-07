function Get-SEPMPolicyXML {
    <#
    .SYNOPSIS
        Gets policy details in XML format
    .DESCRIPTION
        Gets policy details in XML format.

    .PARAMETER PolicyName    
        The name of the policy to get the details of
        Is a required parameter
    .PARAMETER SkipCertificateCheck
        Skip certificate check
    .OUTPUTS
        XML object of the policy details
        Typename: System.Xml.XmlDocument
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPMPolicyXML -PolicyName "Standard Servers - Firewall policy"

        xml                            SchemaContainer
        ---                            ---------------
        version="1.0" encoding="UTF-8" SchemaContainer

        Gets a PowerShell XML object of the policy details
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
        $URI = $script:BaseURLv1 + "/policies/raw"
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
        }

        # Updating URI with policy ID
        $URI = $URI + "/" + $policy_type + "/" + $policyID
        
        # prepare the parameters
        $params = @{
            Method  = 'GET'
            Uri     = $URI
            headers = $headers
        }

        try {
            $resp = Invoke-RestMethod @params -SkipCertificateCheck
        } catch {
            Write-Warning -Message "Error: $_"
        }

        [xml]$xmlContent = $resp.policy_xml
        return $xmlContent
    }
}