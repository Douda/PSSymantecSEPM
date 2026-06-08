<#
.SYNOPSIS
    Seeds SEPM with file fingerprint lists (blacklists).

.DESCRIPTION
    Reads Source/Seed/Fingerprints.psd1 and creates fingerprint lists
    on the SEPM server via POST to /api/v1/policy-objects/fingerprints.
    Retrieves the Default domain ID at runtime via GET /api/v1/domains.
    Idempotent — skips fingerprint lists whose name already exists.

    On -Force: deletes existing seed fingerprint lists by name lookup before recreating.

.PARAMETER State
    Shared state hashtable from the orchestrator. Must contain at least:
    - Session (PSCustomObject): session from Initialize-SEPMSession
    - Force (bool): whether to delete and recreate fingerprint lists.

.EXAMPLE
    Invoke-SeedFingerprints -State @{ Force = $false; Session = $session }

    Creates all seed fingerprint lists (idempotent).

.EXAMPLE
    Invoke-SeedFingerprints -State @{ Force = $true; Session = $session }

    Deletes existing seed fingerprint lists, then recreates.
#>

#Requires -Version 5.1

function Invoke-SeedFingerprints {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable] $State
    )

    # Load the Fingerprints data file
    $scriptDir = Split-Path -Path $PSScriptRoot -Parent
    if (Test-Path (Join-Path -Path $scriptDir -ChildPath 'Source/Seed/Fingerprints.psd1')) {
        $seedDir = Join-Path -Path $scriptDir -ChildPath 'Source/Seed'
    } else {
        $seedDir = Join-Path -Path $PSScriptRoot -ChildPath 'Source/Seed'
    }
    $data = Import-PowerShellDataFile -Path (Join-Path -Path $seedDir -ChildPath 'Fingerprints.psd1') -ErrorAction Stop

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

    # ── Get Default domain ID ──
    $domainsResp = _InvokeApi -Method GET -Uri "$($session.BaseURLv1)/domains" -Session $session
    $defaultDomain = $domainsResp | Where-Object { $_.name -eq 'Default' } | Select-Object -First 1
    $domainId = if ($defaultDomain) { $defaultDomain.id } else { $null }

    # State table: fingerprint list name -> ID
    $fingerprintMap = @{}

    # ── Force reset: delete existing seed fingerprint lists ──
    $forceResetNames = [System.Collections.Generic.List[string]]::new()
    if ($State.Force) {
        $seedNames = $data.Fingerprints.Name
        foreach ($fpName in $seedNames) {
            $existing = _InvokeApi -Method GET -Uri "$($session.BaseURLv1)/policy-objects/fingerprints?name=$([System.Uri]::EscapeDataString($fpName))" -Session $session
            if ($existing -and $existing.id) {
                $null = $forceResetNames.Add($fpName)
                $delResp = _InvokeApi -Method DELETE -Uri "$($session.BaseURLv1)/policy-objects/fingerprints/$($existing.id)" -Session $session
                if ($delResp -is [string] -and $delResp -like 'Error:*') {
                    Write-Warning "Failed to delete fingerprint list '$fpName': $delResp. Will recreate anyway."
                }
            }
        }
    }

    # ── Create each fingerprint list ──
    foreach ($entry in $data.Fingerprints) {
        # Check idempotency
        $existing = _InvokeApi -Method GET -Uri "$($session.BaseURLv1)/policy-objects/fingerprints?name=$([System.Uri]::EscapeDataString($entry.Name))" -Session $session
        if ($existing -and $existing.id -and $entry.Name -notin $forceResetNames) {
            $fingerprintMap[$entry.Name] = $existing.id
            continue
        }

        # Inject runtime domainId
        $postBody = @{
            name        = $entry.Name
            domainId    = $domainId
            hashType    = $entry.HashType
            description = $entry.Description
            data        = $entry.Data
        } | ConvertTo-Json -Depth 10 -Compress

        $createUri = "$($session.BaseURLv1)/policy-objects/fingerprints"
        $createResp = _InvokeApi -Method POST -Uri $createUri -Session $session -Body $postBody

        if ($createResp -and $createResp.id) {
            $fingerprintMap[$entry.Name] = $createResp.id
        } else {
            Write-Warning "Failed to create fingerprint list '$($entry.Name)'"
            $fingerprintMap[$entry.Name] = $null
        }
    }

    $State['FingerprintMap'] = $fingerprintMap
    return $State
}
