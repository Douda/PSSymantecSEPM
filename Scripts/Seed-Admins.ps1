<#
.SYNOPSIS
    Seeds SEPM with Administrator accounts.

.DESCRIPTION
    Reads Source/Seed/Admins.psd1 and creates administrator accounts
    on the SEPM server via POST to /api/v1/admin-users. Idempotent —
    skips admins whose loginName already exists.

    On -Force: warns that admin deletion is not supported (no DELETE
    endpoint exists), then proceeds to create/update.

.PARAMETER State
    Shared state hashtable from the orchestrator. Must contain at least:
    - Session (PSCustomObject): session from Initialize-SEPMSession
    - Force (bool): whether to attempt reset (admin deletion is skipped)

.EXAMPLE
    Invoke-SeedAdmins -State @{ Force = $false; Session = $session }

    Creates all seed admins (idempotent).

.EXAMPLE
    Invoke-SeedAdmins -State @{ Force = $true; Session = $session }

    Warns about admin deletion skip, then creates.
#>

#Requires -Version 5.1

function Invoke-SeedAdmins {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable] $State
    )

    # Load the Admins data file
    $scriptDir = Split-Path -Path $PSScriptRoot -Parent
    if (Test-Path (Join-Path -Path $scriptDir -ChildPath 'Source/Seed/Admins.psd1')) {
        $seedDir = Join-Path -Path $scriptDir -ChildPath 'Source/Seed'
    } else {
        $seedDir = Join-Path -Path $PSScriptRoot -ChildPath 'Source/Seed'
    }
    $data = Import-PowerShellDataFile -Path (Join-Path -Path $seedDir -ChildPath 'Admins.psd1') -ErrorAction Stop

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
            # Fallback for Pester tests: Mock makes Invoke-SepmApi available
            if ($Body) {
                return Invoke-SepmApi -Method $Method -Uri $Uri -Session $Session -Body $Body
            } else {
                return Invoke-SepmApi -Method $Method -Uri $Uri -Session $Session
            }
        }
    }

    # State table: loginName -> admin ID
    $adminMap = @{}

    # ── Force reset: warn and skip admin deletion ──
    if ($State.Force) {
        Write-Warning 'Force mode: Administrators cannot be deleted via SEPM REST API (no DELETE endpoint). Skipping admin deletion.'
    }

    # ── Get existing admins (for idempotency check) ──
    $existingAdmins = _InvokeApi -Method GET -Uri "$($session.BaseURLv1)/admin-users" -Session $session

    # Build lookup: loginName -> id from existing admins
    $existingLookup = @{}
    if ($existingAdmins -and $existingAdmins -isnot [string]) {
        foreach ($admin in $existingAdmins) {
            if ($admin -is [hashtable] -or $admin -is [pscustomobject]) {
                if ($admin.ContainsKey('loginName') -and $admin.ContainsKey('id')) {
                    $existingLookup[$admin.loginName] = $admin.id
                }
            }
        }
    }

    # ── Create each admin (skip existing) ──
    foreach ($entry in $data.Admins) {
        if ($existingLookup.ContainsKey($entry.loginName)) {
            # Already exists — use existing ID
            $adminMap[$entry.loginName] = $existingLookup[$entry.loginName]
            continue
        }

        # Build POST body
        $body = @{
            loginName             = $entry.loginName
            fullName              = $entry.fullName
            adminType             = $entry.adminType
            emailAddress          = $entry.emailAddress
            password              = $entry.password
            authenticationMethod  = 0
            enabled               = $true
            lockTimeThreshold     = 15
            loginAttemptThreshold = 3
            lockAccount           = $false
            notifyAdminOfLockedState = $false
        } | ConvertTo-Json

        $uri = "$($session.BaseURLv1)/admin-users"
        $resp = _InvokeApi -Method POST -Uri $uri -Session $session -Body $body

        # POST returns the full object with ID
        if ($resp -and $resp -isnot [string] -and $resp.ContainsKey('id')) {
            $adminMap[$entry.loginName] = $resp.id
        } else {
            Write-Warning "Unexpected response for $($entry.loginName). No ID returned. Response: $resp"
            $adminMap[$entry.loginName] = $null
        }
    }

    # Merge AdminMap into State (preserve existing keys + Force + Session)
    $State['AdminMap'] = $adminMap
    return $State
}
