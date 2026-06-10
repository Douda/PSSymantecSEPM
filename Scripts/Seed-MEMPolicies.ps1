<#
.SYNOPSIS
    Seeds SEPM with Memory Exploit Mitigation (MEM) Policies.

.DESCRIPTION
    Reads Source/Seed/MEMPolicies.psd1 and creates MEM policies
    on the SEPM server via POST to /api/v1/policies/mem followed by
    PATCH with full configuration. Idempotent — skips policies whose name
    already exists.

    On -Force: deletes existing seed policies by name lookup before recreating.

.PARAMETER State
    Shared state hashtable from the orchestrator. Must contain at least:
    - Session (PSCustomObject): session from Initialize-SEPMSession
    - Force (bool): whether to delete and recreate policies.

.EXAMPLE
    Invoke-SeedMEMPolicies -State @{ Force = $false; Session = $session }

    Creates all seed MEM policies (idempotent).

.EXAMPLE
    Invoke-SeedMEMPolicies -State @{ Force = $true; Session = $session }

    Deletes existing seed MEM policies, then recreates.
#>

#Requires -Version 5.1

function Invoke-SeedMEMPolicies {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable] $State
    )

    # Load the MEMPolicies data file
    $scriptDir = Split-Path -Path $PSScriptRoot -Parent
    if (Test-Path (Join-Path -Path $scriptDir -ChildPath 'Source/Seed/MEMPolicies.psd1')) {
        $seedDir = Join-Path -Path $scriptDir -ChildPath 'Source/Seed'
    } else {
        $seedDir = Join-Path -Path $PSScriptRoot -ChildPath 'Source/Seed'
    }
    $data = Import-PowerShellDataFile -Path (Join-Path -Path $seedDir -ChildPath 'MEMPolicies.psd1') -ErrorAction Stop

    $session = $State.Session

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

    # ── Force reset: delete existing seed policies ──
    if ($State.Force) {
        $seedNames = $data.Policies.Name

        # Get current policies to find IDs
        $currentPolicies = _InvokeApi -Method GET -Uri "$($session.BaseURLv1)/policies/summary/mem" -Session $session
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
                _InvokeApi -Method PATCH -Uri "$($session.BaseURLv1)/policies/mem/$($existing.id)" `
                    -Session $session -Body $disableBody

                _InvokeApi -Method DELETE -Uri "$($session.BaseURLv1)/policies/mem/$($existing.id)" `
                    -Session $session
            }
        }
    }

    # ── Get existing policies for idempotency check ──
    $existingPolicies = _InvokeApi -Method GET -Uri "$($session.BaseURLv1)/policies/summary/mem" -Session $session
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

    # ── Create each policy ──
    foreach ($entry in $data.Policies) {
        if ($existingLookup.ContainsKey($entry.Name)) {
            $policyMap[$entry.Name] = $existingLookup[$entry.Name]
            continue
        }

        # Step 1: POST with full configuration
        # Note: SEPM 14.3 honors config.enabled and globalauditmodeoverride on POST
        #       but ignores them on PATCH. Always send all config in POST body.
        $config = $entry.Configuration.Clone()
        $postBody = @{
            name          = $entry.Name
            desc          = $entry.Description
            enabled       = $entry.Enabled
            configuration = $config
        } | ConvertTo-Json -Depth 10 -Compress

        $createUri = "$($session.BaseURLv1)/policies/mem"
        $null = _InvokeApi -Method POST -Uri $createUri -Session $session -Body $postBody

        # Step 2: GET summary to retrieve server-assigned ID (POST returns empty body)
        $summaryResp = _InvokeApi -Method GET -Uri "$($session.BaseURLv1)/policies/summary/mem" -Session $session
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

        $policyMap[$entry.Name] = $policyId
    }

    # Merge MEMPolicyMap into State
    $State['MEMPolicyMap'] = $policyMap
    return $State
}
