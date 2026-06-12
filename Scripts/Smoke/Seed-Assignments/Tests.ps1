<#
.SYNOPSIS
    Shared smoke tests for Seed-Assignments.

.DESCRIPTION
    Dot-sourced by run.ps7.ps1 and run.ps51.ps1 after Common.ps1.
    Verifies the Assignments seed data file structure and content.
#>

Write-Host "=== Smoke: Seed-Assignments ==="

# Verify data file exists
$dataFile = Join-Path -Path $RepoRoot -ChildPath 'Source/Seed/Assignments.psd1'
if (-not (Test-Path $dataFile)) {
    Write-Host "  ERROR: Assignments.psd1 not found at $dataFile"
    exit 1
}

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

# ── Summary ──
Write-Summary -Results $results -Label "Seed-Assignments Smoke Tests"
