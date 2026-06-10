<#
.SYNOPSIS
    Seeds SEPM with policy-to-group assignments.

.DESCRIPTION
    Reads Source/Seed/Assignments.psd1 and creates policy-to-group assignments
    on the SEPM server. Each entry references groups by suffix pattern (e.g.,
    *\Servers) and policies by name. Resolves names against the state tables
    populated by prior seed functions (GroupMap, ExceptionPolicyMap, etc.).

    Assignments are idempotent -- PUT is upsert by nature.

.PARAMETER State
    Shared state hashtable from the orchestrator. Must contain at least:
    - Session: session from Initialize-SEPMSession
    - Force: whether in force-reset mode
    - GroupMap: fullPathName -> group ID (from Invoke-SeedGroups)
    - ExceptionPolicyMap, MEMPolicyMap, UpgradePolicyMap, TDADPolicyMap: name -> ID
    - FingerprintMap: name -> fingerprint ID (from Invoke-SeedFingerprints)

.EXAMPLE
    Invoke-SeedAssignments -State $State

    Creates all seed assignments (idempotent).
#>

#Requires -Version 5.1

function Invoke-SeedAssignments {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable] $State
    )

    # Load the Assignments data file
    $scriptDir = Split-Path -Path $PSScriptRoot -Parent
    if (Test-Path (Join-Path -Path $scriptDir -ChildPath 'Source/Seed/Assignments.psd1')) {
        $seedDir = Join-Path -Path $scriptDir -ChildPath 'Source/Seed'
    } else {
        $seedDir = Join-Path -Path $PSScriptRoot -ChildPath 'Source/Seed'
    }
    $data = Import-PowerShellDataFile -Path (Join-Path -Path $seedDir -ChildPath 'Assignments.psd1') -ErrorAction Stop

    $session = $State.Session
    $baseUrl = $session.BaseURLv1

    # Helper: call Invoke-SepmApi through module scope (live) or directly (tests with Mock)
    function _InvokeApi {
        param([string]$Method, [string]$Uri, $Session, [string]$Body, [string]$ContentType)

        if ($State.ContainsKey('Module') -and $State.Module) {
            return & $State.Module {
                param($M, $U, $S, $B, $C)
                $callParams = @{ Method = $M; Uri = $U; Session = $S }
                if ($B) { $callParams['Body'] = $B }
                if ($C) { $callParams['ContentType'] = $C }
                Invoke-SepmApi @callParams
            } -M $Method -U $Uri -S $Session -B $Body -C $ContentType
        } else {
            $callParams = @{ Method = $Method; Uri = $Uri; Session = $Session }
            if ($Body) { $callParams['Body'] = $Body }
            if ($ContentType) { $callParams['ContentType'] = $ContentType }
            return Invoke-SepmApi @callParams
        }
    }

    # Policy type -> State map key lookup
    $policyMapLookup = @{
        exceptions = 'ExceptionPolicyMap'
        mem        = 'MEMPolicyMap'
        upgrade    = 'UpgradePolicyMap'
        tdad       = 'TDADPolicyMap'
    }

    $assignmentCount = 0

    foreach ($entry in $data.Assignments) {
        $suffixPattern = $entry.groupPath

        # Find matching groups in GroupMap
        $matchingGroups = $State.GroupMap.Keys | Where-Object { $_ -like $suffixPattern }

        # Exclude groups that have subgroup children in GroupMap
        # (e.g., skip London Workstations if London\Workstations\HR Exception Machines exists)
        $matchingGroups = $matchingGroups | Where-Object {
            $parentPath = $_
            $hasChildren = $State.GroupMap.Keys | Where-Object {
                $_ -ne $parentPath -and $_ -like "$parentPath\*"
            }
            if ($hasChildren) {
                Write-Verbose "Skipping '$parentPath' -- has subgroup children in GroupMap"
                return $false
            }
            return $true
        }

        if ($matchingGroups.Count -eq 0) {
            Write-Warning "No groups matched suffix pattern '$suffixPattern'"
            continue
        }

        $policyType = $entry.policyType

        # Handle fingerprint assignments
        if ($policyType -eq 'fingerprint') {
            $fpName = $entry.fingerprintName
            $fpId = $State.FingerprintMap[$fpName]
            if (-not $fpId) {
                Write-Warning "Fingerprint '$fpName' not found in FingerprintMap"
                continue
            }
            foreach ($groupPath in $matchingGroups) {
                $groupId = $State.GroupMap[$groupPath]
                $uri = "$baseUrl/groups/$groupId/system-lockdown/fingerprints/$fpId"
                $null = _InvokeApi -Method PUT -Uri $uri -Session $session
                $assignmentCount++
            }
            continue
        }

        # Resolve policy ID from appropriate map
        $mapKey = $policyMapLookup[$policyType]
        $policyMap = $State[$mapKey]
        $policyName = $entry.policyName
        $policyId = $policyMap[$policyName]

        if (-not $policyId) {
            Write-Warning "Policy '$policyName' (type: $policyType) not found in $mapKey"
            continue
        }

        foreach ($groupPath in $matchingGroups) {
            $groupId = $State.GroupMap[$groupPath]
            $uri = "$baseUrl/groups/$groupId/locations/default/policies/$policyType"
            $body = @{ id = $policyId } | ConvertTo-Json -Compress
            $null = _InvokeApi -Method PUT -Uri $uri -Session $session -Body $body
            $assignmentCount++
        }
    }

    $State['AssignmentCount'] = $assignmentCount
    return $State
}
