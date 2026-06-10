<#
.SYNOPSIS
    Seeds SEPM with Exception Policies.

.DESCRIPTION
    Reads Source/Seed/ExceptionsPolicies.psd1 and creates exception policies
    on the SEPM server via POST to /api/v1/policies/exceptions followed by
    PATCH with full configuration. Idempotent -- skips policies whose name
    already exists.

    On -Force: deletes existing seed policies by name lookup before recreating.

.PARAMETER State
    Shared state hashtable from the orchestrator. Must contain at least:
    - Session (PSCustomObject): session from Initialize-SEPMSession
    - Force (bool): whether to delete and recreate policies.

.EXAMPLE
    Invoke-SeedExceptionsPolicies -State @{ Force = $false; Session = $session }

    Creates all seed exception policies (idempotent).

.EXAMPLE
    Invoke-SeedExceptionsPolicies -State @{ Force = $true; Session = $session }

    Deletes existing seed policies, then recreates.
#>

#Requires -Version 5.1

function Invoke-SeedExceptionsPolicies {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable] $State
    )

    # Load the ExceptionsPolicies data file
    $scriptDir = Split-Path -Path $PSScriptRoot -Parent
    if (Test-Path (Join-Path -Path $scriptDir -ChildPath 'Source/Seed/ExceptionsPolicies.psd1')) {
        $seedDir = Join-Path -Path $scriptDir -ChildPath 'Source/Seed'
    } else {
        $seedDir = Join-Path -Path $PSScriptRoot -ChildPath 'Source/Seed'
    }
    $data = Import-PowerShellDataFile -Path (Join-Path -Path $seedDir -ChildPath 'ExceptionsPolicies.psd1') -ErrorAction Stop

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

    # State table: policy name -> policy ID
    $policyMap = @{}

    # ------ Force reset: delete existing seed policies ------
    if ($State.Force) {
        $seedNames = $data.Policies.Name

        # Get current policies to find IDs
        $currentPolicies = _InvokeApi -Method GET -Uri "$baseUrl/policies/summary/exceptions" -Session $session
        $currentContent = if ($currentPolicies -and $currentPolicies.ContainsKey('content')) {
            $currentPolicies.content
        } else {
            $currentPolicies
        }

        foreach ($policyName in $seedNames) {
            $existing = $currentContent | Where-Object { $_.name -eq $policyName } | Select-Object -First 1
            if ($existing -and $existing.id) {
                # Disable first (required for unassigned deletion)
                $disableBody = @{ name = $policyName; enabled = $false } | ConvertTo-Json
                _InvokeApi -Method PATCH -Uri "$baseUrl/policies/exceptions/$($existing.id)" `
                    -Session $session -Body $disableBody

                _InvokeApi -Method DELETE -Uri "$baseUrl/policies/exceptions/$($existing.id)" `
                    -Session $session
            }
        }
    }

    # ------ Get existing policies for idempotency check ------
    $existingPolicies = _InvokeApi -Method GET -Uri "$baseUrl/policies/summary/exceptions" -Session $session
    $existingContent = if ($existingPolicies -and $existingPolicies.ContainsKey('content')) {
        $existingPolicies.content
    } else {
        $existingPolicies
    }

    # Build lookup: name -> id
    $existingLookup = @{}
    if ($existingContent) {
        foreach ($p in $existingContent) {
            if (($p -is [hashtable] -or $p -is [pscustomobject]) -and $p.ContainsKey('name') -and $p.ContainsKey('id')) {
                $existingLookup[$p.name] = $p.id
            }
        }
    }

    # Helper: enrich a config entry from PSD1 with required PATCH fields
    function _EnrichConfigEntry {
        param($Entry, [string]$Type)

        $enriched = @{ deleted = $false }
        $enriched['rulestate'] = @{ enabled = $true; source = 'PSSymantecSEPM' }

        # Copy all keys from the entry
        foreach ($key in $Entry.Keys) {
            $enriched[$key] = $Entry[$key]
        }

        return $enriched
    }

    # ------ Create each policy ------
    foreach ($entry in $data.Policies) {
        if ($existingLookup.ContainsKey($entry.Name)) {
            $policyMap[$entry.Name] = $existingLookup[$entry.Name]
            continue
        }

        # Step 1: POST minimal payload to create policy
        $postBody = @{
            name    = $entry.Name
            desc    = $entry.Description
            enabled = $entry.Enabled
        } | ConvertTo-Json

        $createUri = "$baseUrl/policies/exceptions"
        $null = _InvokeApi -Method POST -Uri $createUri -Session $session -Body $postBody

        # Step 2: GET summary to retrieve server-assigned ID
        $summaryResp = _InvokeApi -Method GET -Uri "$baseUrl/policies/summary/exceptions" -Session $session
        $summaryContent = if ($summaryResp -and $summaryResp.ContainsKey('content')) {
            $summaryResp.content
        } else {
            $summaryResp
        }

        $createdPolicy = $summaryContent | Where-Object { $_.name -eq $entry.Name } | Select-Object -First 1
        if (-not $createdPolicy -or -not $createdPolicy.id) {
            Write-Warning "Failed to find ID for newly created policy '$($entry.Name)'"
            $policyMap[$entry.Name] = $null
            continue
        }
        $policyId = $createdPolicy.id

        # Step 3: Build PATCH body with full configuration
        $config = @{}
        if ($entry.Configuration.ContainsKey('files') -and $entry.Configuration.files.Count -gt 0) {
            $config['files'] = @($entry.Configuration.files | ForEach-Object { _EnrichConfigEntry $_ 'file' })
        }
        if ($entry.Configuration.ContainsKey('directories') -and $entry.Configuration.directories.Count -gt 0) {
            $config['directories'] = @($entry.Configuration.directories | ForEach-Object { _EnrichConfigEntry $_ 'directory' })
        }
        if ($entry.Configuration.ContainsKey('extension_list')) {
            $ext = $entry.Configuration.extension_list
            $config['extension_list'] = @{
                deleted    = $false
                rulestate  = @{ enabled = $true; source = 'PSSymantecSEPM' }
                extensions = $ext.extensions
                scantype   = $ext.scantype
            }
        }
        if ($entry.Configuration.ContainsKey('tamper_files') -and $entry.Configuration.tamper_files.Count -gt 0) {
            $config['tamper_files'] = @($entry.Configuration.tamper_files | ForEach-Object { _EnrichConfigEntry $_ 'tamper' })
        }

        $patchBody = @{
            name          = $entry.Name
            configuration = $config
        } | ConvertTo-Json -Depth 10 -Compress

        $patchUri = "$baseUrl/policies/exceptions/$policyId"
        $null = _InvokeApi -Method PATCH -Uri $patchUri -Session $session -Body $patchBody

        $policyMap[$entry.Name] = $policyId
    }

    # Merge ExceptionPolicyMap into State
    $State['ExceptionPolicyMap'] = $policyMap
    return $State
}
