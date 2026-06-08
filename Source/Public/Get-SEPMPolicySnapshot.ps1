function Get-SEPMPolicySnapshot {
    <#
    .SYNOPSIS
        Creates a snapshot of policies, summaries, and location mappings.
    .DESCRIPTION
        Creates a SEPM.PolicySnapshot PSObject containing full policy objects,
        policy summaries, and a location-id-to-name map for the specified policy types.
    .PARAMETER PolicyType
        The policy types to include in the snapshot. Valid values: fw, ips, exceptions.
    .PARAMETER DelayMs
        Delay in milliseconds between individual policy fetches. Default: 200.
        Forwarded to Get-SEPMFirewallPolicy -All.
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPMPolicySnapshot -PolicyType fw

        Creates a snapshot containing firewall policies, summaries, and location map.
#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('fw', 'ips', 'exceptions')]
        [string[]]
        $PolicyType,

        [Parameter()]
        [int]
        $DelayMs = 200
    )

    begin {
        $snap = New-Object PSObject
        $snap.PSObject.TypeNames.Insert(0, 'SEPM.PolicySnapshot')

        # Build LocationMap once — shared across all policy types
        $locationMap = @{}
        Get-SEPMGroups | Get-SEPMLocation | ForEach-Object {
            $locationMap[$_.locationId] = $_.locationName
        }
    }

    process {
        $snap | Add-Member -MemberType NoteProperty -Name 'FetchedAt' -Value (Get-Date)
        $snap | Add-Member -MemberType NoteProperty -Name 'LocationMap' -Value $locationMap

        foreach ($type in $PolicyType) {
            $typeObject = New-Object PSObject
            $typeUpper = $type.ToUpper()

            switch ($type) {
                'fw' {
                    $typeObject | Add-Member -MemberType NoteProperty -Name 'Policies' -Value (Get-SEPMFirewallPolicy -All -DelayMs $DelayMs)
                    $typeObject | Add-Member -MemberType NoteProperty -Name 'Summary' -Value (Get-SEPMPoliciesSummary -PolicyType fw)
                }
                default {
                    # Future policy types (ips, exceptions) — empty placeholders
                    $typeObject | Add-Member -MemberType NoteProperty -Name 'Policies' -Value @()
                    $typeObject | Add-Member -MemberType NoteProperty -Name 'Summary'  -Value @()
                }
            }

            $snap | Add-Member -MemberType NoteProperty -Name $typeUpper -Value $typeObject
        }

        return $snap
    }
}
