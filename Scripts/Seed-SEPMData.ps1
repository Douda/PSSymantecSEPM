<#
.SYNOPSIS
    Seeds a SEPM server with test data across multiple categories.

.DESCRIPTION
    Master orchestrator for all seed operations. Imports the PSSymantecSEPM module,
    authenticates via Initialize-SEPMSession, and dispatches to per-category seed
    functions based on the -Categories parameter.

.PARAMETER Categories
    Which seed categories to run. Valid values: Test (framework diagnostic).
    Default: all categories.

.PARAMETER Force
    Enables reset-before-create mode. Passed through to per-category functions via
    $State.Force.

.EXAMPLE
    Seed-SEPMData.ps1 -Categories Test

    Imports the module, authenticates, prints "Framework ready", and exits.

.EXAMPLE
    Seed-SEPMData.ps1

    Runs all seed categories (currently prints "No categories implemented yet").
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string[]] $Categories,

    [switch] $Force
)

$ErrorActionPreference = 'Continue'

# Import the PSSymantecSEPM module
$module = Import-Module PSSymantecSEPM -PassThru -Force
& $module { $script:SkipCert = $true }

# Authenticate and create session (Private function, called via module scope)
$session = & $module { Initialize-SEPMSession }

# Set up shared state lookup table for name-to-ID mappings across categories
$State = @{ Force = $false; Module = $module; Session = $session }
if ($Force) {
    $State.Force = $true
}

# ── Dispatch ──

# Dot-source seed function scripts
$seedGroupsScript = Join-Path -Path $PSScriptRoot -ChildPath 'Seed-Groups.ps1'
. $seedGroupsScript

$seedAdminsScript = Join-Path -Path $PSScriptRoot -ChildPath 'Seed-Admins.ps1'
. $seedAdminsScript

$seedExceptionsPoliciesScript = Join-Path -Path $PSScriptRoot -ChildPath 'Seed-ExceptionsPolicies.ps1'
. $seedExceptionsPoliciesScript

$seedMEMPoliciesScript = Join-Path -Path $PSScriptRoot -ChildPath 'Seed-MEMPolicies.ps1'
. $seedMEMPoliciesScript

$seedUpgradePoliciesScript = Join-Path -Path $PSScriptRoot -ChildPath 'Seed-UpgradePolicies.ps1'
. $seedUpgradePoliciesScript

$seedTDADPoliciesScript = Join-Path -Path $PSScriptRoot -ChildPath 'Seed-TDADPolicies.ps1'
. $seedTDADPoliciesScript

$seedHostGroupsScript = Join-Path -Path $PSScriptRoot -ChildPath 'Seed-HostGroups.ps1'
. $seedHostGroupsScript

$seedFingerprintsScript = Join-Path -Path $PSScriptRoot -ChildPath 'Seed-Fingerprints.ps1'
. $seedFingerprintsScript

$seedAssignmentsScript = Join-Path -Path $PSScriptRoot -ChildPath 'Seed-Assignments.ps1'
. $seedAssignmentsScript

# If no categories specified, default to all
if (-not $Categories -or $Categories.Count -eq 0) {
    Write-Output 'No categories implemented yet'
    return
}

# Top-level dispatch switch
switch -Regex ($Categories) {
    '^Test$' {
        Write-Output 'Framework ready'
        Write-Output "Force: $($State.Force)"
    }
    '^Groups$' {
        Write-Output '=== Seeding Groups ==='
        $result = Invoke-SeedGroups -State $State
        Write-Output "Groups seeded: $($result.GroupMap.Count)"
    }
    '^Admins$' {
        Write-Output '=== Seeding Admins ==='
        $result = Invoke-SeedAdmins -State $State
        Write-Output "Admins seeded: $($result.AdminMap.Count)"
    }
    '^ExceptionsPolicies$' {
        Write-Output '=== Seeding Exceptions Policies ==='
        $result = Invoke-SeedExceptionsPolicies -State $State
        Write-Output "Exceptions policies seeded: $($result.ExceptionPolicyMap.Count)"
    }
    '^MEMPolicies$' {
        Write-Output '=== Seeding MEM Policies ==='
        $result = Invoke-SeedMEMPolicies -State $State
        Write-Output "MEM policies seeded: $($result.MEMPolicyMap.Count)"
    }
    '^UpgradePolicies$' {
        Write-Output '=== Seeding Upgrade Policies ==='
        $result = Invoke-SeedUpgradePolicies -State $State
        Write-Output "Upgrade policies seeded: $($result.UpgradePolicyMap.Count)"
    }
    '^TDADPolicies$' {
        Write-Output '=== Seeding TDAD Policies ==='
        $result = Invoke-SeedTDADPolicies -State $State
        Write-Output "TDAD policies seeded: $($result.TDADPolicyMap.Count)"
    }
    '^HostGroups$' {
        Write-Output '=== Seeding Host Groups ==='
        $result = Invoke-SeedHostGroups -State $State
        Write-Output "Host groups seeded: $($result.HostGroupMap.Count)"
    }
    '^Fingerprints$' {
        Write-Output '=== Seeding Fingerprints ==='
        $result = Invoke-SeedFingerprints -State $State
        Write-Output "Fingerprints seeded: $($result.FingerprintMap.Count)"
    }
    '^Assignments$' {
        Write-Output '=== Seeding Assignments ==='
        $result = Invoke-SeedAssignments -State $State
        Write-Output "Assignments created: $($result.AssignmentCount)"
    }
}
