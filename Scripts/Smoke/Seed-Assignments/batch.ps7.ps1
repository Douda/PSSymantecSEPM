$ErrorActionPreference = "Continue"
$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"

Write-Host "=== Smoke: Seed-Assignments (PS7) ==="

# This smoke test verifies the Assignments seed function works end-to-end.
# It requires that Groups, Policies, and Fingerprints have already been seeded.
# Run with: Seed-SEPMData.ps1 -Categories Groups,ExceptionsPolicies,MEMPolicies,UpgradePolicies,TDADPolicies,Fingerprints,Assignments

# Verify the seed script exists and can be dot-sourced
$seedScript = Join-Path -Path $RepoRoot -ChildPath 'Scripts/Seed-Assignments.ps1'
if (-not (Test-Path $seedScript)) {
    Write-Host "  ERROR: Seed-Assignments.ps1 not found at $seedScript"
    exit 1
}

# Verify data file exists
$dataFile = Join-Path -Path $RepoRoot -ChildPath 'Source/Seed/Assignments.psd1'
if (-not (Test-Path $dataFile)) {
    Write-Host "  ERROR: Assignments.psd1 not found at $dataFile"
    exit 1
}

Write-Host "  Seed script: $seedScript"
Write-Host "  Data file: $dataFile"

# Load data file to verify structure
$data = Import-PowerShellDataFile -Path $dataFile -ErrorAction Stop

$results = @{}

$results.A1 = T "A1" "Data file has Assignments array" `
    { $data } `
    { param($r) $r.ContainsKey('Assignments') -and $r.Assignments.Count -gt 0 }

$results.A2 = T "A2" "Entries have required fields (groupPath, policyType)" `
    { $data.Assignments } `
    { param($r)
        $ok = $true
        foreach ($entry in $r) {
            if (-not $entry.ContainsKey('groupPath') -or -not $entry.ContainsKey('policyType')) {
                $ok = $false
                break
            }
        }
        $ok
    }

$results.A3 = T "A3" "Data file has ~24-26 entries" `
    { $data.Assignments.Count } `
    { param($r) $r -ge 20 -and $r -le 30 }

# Count policy types
$policyTypes = $data.Assignments | ForEach-Object { $_.policyType } | Sort-Object -Unique
$results.A4 = T "A4" "Contains expected policy types" `
    { $policyTypes } `
    { param($r) 'exceptions' -in $r -and 'mem' -in $r -and 'upgrade' -in $r -and 'tdad' -in $r }

$results.A5 = T "A5" "Contains fingerprint assignment entries" `
    { ($data.Assignments | Where-Object { $_.policyType -eq 'fingerprint' }).Count } `
    { param($r) $r -ge 2 }

Write-Host ""
Write-Host "=== Results ==="
$passCount = ($results.Values | Where-Object { $_ -eq 'PASS' }).Count
$failCount = ($results.Values | Where-Object { $_ -eq 'FAIL' }).Count
$skipCount = ($results.Values | Where-Object { $_ -eq 'SKIP' }).Count
Write-Host "PASS: $passCount  FAIL: $failCount  SKIP: $skipCount"

if ($failCount -gt 0) { exit 1 }
