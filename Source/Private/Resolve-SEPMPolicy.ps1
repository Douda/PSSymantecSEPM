function Resolve-SEPMPolicy {
    <#
    .SYNOPSIS
        Resolves a policy name to its ID, with optional type validation.

    .DESCRIPTION
        Accepts a policy name, expected policy type, and an optional pre-fetched policy list.
        Fetches summaries (or reuses the provided list), matches by name, validates the type,
        and returns the policy ID. Throws a clear error if the policy is not found or if the
        type does not match the expected value.

        This is a private helper — it is not exported. Callers include Update-SEPMExceptionPolicy,
        Get-SEPMFirewallPolicy, Get-SEPMIpsPolicy, and Get-SEPMExceptionPolicy.

    .PARAMETER PolicyName
        The name of the policy to resolve.

    .PARAMETER PolicyType
        The expected policy type. Must be one of: fw, ips, exceptions.

    .PARAMETER PolicyList
        Optional pre-fetched array of policy summary objects from Get-SEPMPoliciesSummary.
        When provided, skips the internal summary fetch. When $null or empty, fetches summaries
        via Get-SEPMPoliciesSummary.

    .OUTPUTS
        System.String. The policy ID.

    .EXAMPLE
        # Simple resolution — fetches summaries internally
        $id = Resolve-SEPMPolicy -PolicyName 'My FW Policy' -PolicyType 'fw'

    .EXAMPLE
        # With pre-fetched policy list (avoids redundant API call)
        $summaries = Get-SEPMPoliciesSummary
        $id = Resolve-SEPMPolicy -PolicyName 'My IPS Policy' -PolicyType 'ips' -PolicyList $summaries
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $PolicyName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('fw', 'ips', 'exceptions')]
        [string]
        $PolicyType,

        [Parameter()]
        [object[]]
        $PolicyList
    )

    # Fetch summaries if caller didn't provide a pre-fetched list
    if ($null -eq $PolicyList -or $PolicyList.Count -eq 0) {
        $policies = Get-SEPMPoliciesSummary
    } else {
        $policies = $PolicyList
    }

    # Match by name
    $policy = $policies | Where-Object { $_.name -eq $PolicyName } | Select-Object -First 1

    if (-not $policy) {
        throw "Policy '$PolicyName' not found. Verify the policy name and try again."
    }

    # Validate policy type
    $typeDisplayName = switch ($PolicyType) {
        'fw'         { 'FIREWALL' }
        'ips'        { 'IPS' }
        'exceptions' { 'EXCEPTIONS' }
    }

    if ($policy.policytype -ne $PolicyType) {
        $message = "policy type is not of type $typeDisplayName or does not exist - Please verify the policy name"
        Write-Error -Message $message
        throw $message
    }

    return $policy.id
}
