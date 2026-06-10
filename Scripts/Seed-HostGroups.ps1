<#
.SYNOPSIS
    Seeds SEPM with Host Group policy components.

.DESCRIPTION
    Reads Source/Seed/HostGroups.psd1 and creates host group policy components
    on the SEPM server via POST to /api/v1/policies/policy-objects/hostgroups.
    Idempotent -- skips host groups whose name already exists.

    On -Force: deletes existing seed host groups by name lookup before recreating.

.PARAMETER State
    Shared state hashtable from the orchestrator. Must contain at least:
    - Session (PSCustomObject): session from Initialize-SEPMSession
    - Force (bool): whether to delete and recreate host groups.

.EXAMPLE
    Invoke-SeedHostGroups -State @{ Force = $false; Session = $session }

    Creates all seed host groups (idempotent).

.EXAMPLE
    Invoke-SeedHostGroups -State @{ Force = $true; Session = $session }

    Deletes existing seed host groups, then recreates.
#>

#Requires -Version 5.1

function Invoke-SeedHostGroups {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable] $State
    )

    # Load the HostGroups data file
    $scriptDir = Split-Path -Path $PSScriptRoot -Parent
    if (Test-Path (Join-Path -Path $scriptDir -ChildPath 'Source/Seed/HostGroups.psd1')) {
        $seedDir = Join-Path -Path $scriptDir -ChildPath 'Source/Seed'
    } else {
        $seedDir = Join-Path -Path $PSScriptRoot -ChildPath 'Source/Seed'
    }
    $data = Import-PowerShellDataFile -Path (Join-Path -Path $seedDir -ChildPath 'HostGroups.psd1') -ErrorAction Stop

    $session = $State.Session
    $baseUrl = $session.BaseURLv1

    # Helper: call Invoke-SepmApi through module scope (live) or directly (tests with Mock)
    function _InvokeApi {
        param([string]$Method, [string]$Uri, $Session, [string]$Body)
        if ($State.ContainsKey('Module') -and $State.Module) {
            return & $State.Module {
                param($M, $U, $S, $B)
                if ($B) {
                    Invoke-SepmApi -Method $M -Uri $U -Session $S -Body $B
                } else {
                    Invoke-SepmApi -Method $M -Uri $U -Session $S
                }
            } -M $Method -U $Uri -S $Session -B $Body
        } else {
            if ($Body) {
                return Invoke-SepmApi -Method $Method -Uri $Uri -Session $Session -Body $Body
            } else {
                return Invoke-SepmApi -Method $Method -Uri $Uri -Session $Session
            }
        }
    }

    # State table: host group name -> ID
    $hostGroupMap = @{}

    # ------ Force reset: delete existing seed host groups ------
    $forceResetNames = [System.Collections.Generic.List[string]]::new()
    if ($State.Force) {
        $seedNames = $data.HostGroups.Name

        $currentResp = _InvokeApi -Method GET -Uri "$baseUrl/policies/policy-objects/hostgroups/summary" -Session $session
        $currentContent = if ($currentResp -and $currentResp.ContainsKey('content')) {
            $currentResp.content
        } else {
            $currentResp
        }

        foreach ($hgName in $seedNames) {
            $existing = $currentContent | Where-Object { $_.name -eq $hgName } | Select-Object -First 1
            if ($existing -and $existing.id) {
                $null = $forceResetNames.Add($hgName)
                $delResp = _InvokeApi -Method DELETE -Uri "$baseUrl/policies/policy-objects/hostgroups/$($existing.id)" `
                    -Session $session
                if ($delResp -is [string] -and $delResp -like 'Error:*') {
                    Write-Warning "Failed to delete host group '$hgName': $delResp. Will recreate anyway."
                }
            }
        }
    }

    # ------ Get existing host groups for idempotency check ------
    $existingResp = _InvokeApi -Method GET -Uri "$baseUrl/policies/policy-objects/hostgroups/summary" -Session $session
    $existingContent = if ($existingResp -and $existingResp.ContainsKey('content')) {
        $existingResp.content
    } else {
        $existingResp
    }

    $existingLookup = @{}
    if ($existingContent) {
        foreach ($p in $existingContent) {
            if (($p -is [hashtable] -or $p -is [pscustomobject]) -and $p.ContainsKey('name') -and $p.ContainsKey('id')) {
                $existingLookup[$p.name] = $p.id
            }
        }
    }

    # Force reset: remove names we attempted to delete (even if DELETE failed)
    foreach ($name in $forceResetNames) {
        $existingLookup.Remove($name)
    }

    # ------ Create each host group ------
    foreach ($entry in $data.HostGroups) {
        if ($existingLookup.ContainsKey($entry.Name)) {
            $hostGroupMap[$entry.Name] = $existingLookup[$entry.Name]
            continue
        }

        $postBody = @{
            name  = $entry.Name
            hosts = $entry.Hosts
        } | ConvertTo-Json -Depth 10 -Compress

        $createUri = "$baseUrl/policies/policy-objects/hostgroups"
        $null = _InvokeApi -Method POST -Uri $createUri -Session $session -Body $postBody

        # GET summary to retrieve server-assigned ID
        $summaryResp = _InvokeApi -Method GET -Uri "$baseUrl/policies/policy-objects/hostgroups/summary" -Session $session
        $summaryContent = if ($summaryResp -and $summaryResp.ContainsKey('content')) {
            $summaryResp.content
        } else {
            $summaryResp
        }

        $createdHostGroup = $summaryContent | Where-Object { $_.name -eq $entry.Name } | Sort-Object { if ($_.lastmodifiedtime -is [long]) { $_.lastmodifiedtime } else { 0 } } -Descending | Select-Object -First 1
        if (-not $createdHostGroup -or -not $createdHostGroup.id) {
            Write-Warning "Failed to find ID for newly created host group '$($entry.Name)'"
            $hostGroupMap[$entry.Name] = $null
            continue
        }
        $hostGroupMap[$entry.Name] = $createdHostGroup.id
    }

    # Merge HostGroupMap into State
    $State['HostGroupMap'] = $hostGroupMap
    return $State
}
