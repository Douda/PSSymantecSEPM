function Get-SEPMPolicySnapshot {
    <#
    .SYNOPSIS
        Get a snapshot of SEPM policies and their location mappings.
    .DESCRIPTION
        Assembles a multi-source policy snapshot into a single PSObject.
        Fetches full policies, summaries, and location mappings for the
        specified policy types. Designed for extensibility — adding a
        new policy type adds a property to the snapshot.
    .PARAMETER PolicyType
        The policy types to include in the snapshot. Valid values: fw, ips, exceptions.
    .PARAMETER DelayMs
        Delay in milliseconds between individual policy fetches. Default: 200.
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPMPolicySnapshot -PolicyType fw

        Returns a snapshot with FW policies, FW summaries, and location map.
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
        $snapshot = [PSCustomObject]@{}
        $snapshot.PSObject.TypeNames.Insert(0, 'SEPM.PolicySnapshot')
        $session = Initialize-SEPMSession
        $groups  = Get-SEPMGroups
    }

    process {
        if ('fw' -in $PolicyType) {
            $fwPolicies = Get-SEPMFirewallPolicy -All -DelayMs $DelayMs
            $fwSummary  = Get-SEPMPoliciesSummary -PolicyType fw
            $snapshot | Add-Member -MemberType NoteProperty -Name 'FW' -Value ([PSCustomObject]@{
                Policies = $fwPolicies
                Summary  = $fwSummary
            })
        }

        # Build location map: locationId → locationName
        $locationMap = @{}
        foreach ($g in $groups) {
            # Skip groups with non-string IDs (API returns hashtable IDs for some groups).
            if ($g.id -isnot [string]) { continue }
            $locUri = $session.BaseURLv1 + '/groups/' + $g.id + '/locations'
            $qs = @{ hasName = $true }
            $locUri = Build-SEPMQueryURI -BaseURI $locUri -QueryStrings $qs
            try {
                $resp = Invoke-SepmApi -Method GET -Uri $locUri -Session $session
            } catch {
                continue
            }
            # Normalize response to string array (Invoke-SepmApi returns Object[],
            # hashtable, or string depending on response shape).
            if ($resp -is [array] -and $resp -isnot [string]) {
                $locationStrings = $resp
            } elseif ($resp -is [string]) {
                $locationStrings = @($resp)
            } elseif ($resp -is [hashtable]) {
                $locationStrings = @()
                foreach ($key in $resp.Keys) {
                    if ($key -is [int] -or $key -match '^\d+$') {
                        $locationStrings += $resp[$key]
                    }
                }
            } else {
                continue
            }
            # Skip error responses.
            if ($locationStrings.Count -gt 0 -and $locationStrings[0] -match '^Error') { continue }
            foreach ($location in $locationStrings) {
                $locationMap[$location.split('/')[-1]] = $location.split(':')[0]
            }
        }
        $snapshot | Add-Member -MemberType NoteProperty -Name 'LocationMap' -Value $locationMap

        $snapshot | Add-Member -MemberType NoteProperty -Name 'FetchedAt' -Value ([DateTime]::Now)
    }

    end {
        return $snapshot
    }
}
