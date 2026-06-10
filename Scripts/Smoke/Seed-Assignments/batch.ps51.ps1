$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"
. "$RepoRoot\Common-PS51.ps1"

Write-Host "=== Smoke: Seed-Assignments (PS5.1) ==="

# Verify the seed script exists and can be dot-sourced
$seedScript = Join-Path -Path $RepoRoot -ChildPath 'Scripts\Seed-Assignments.ps1'
if (-not (Test-Path $seedScript)) {
    Write-Host "  ERROR: Seed-Assignments.ps1 not found at $seedScript"
    exit 1
}

# Verify data file exists
$dataFile = Join-Path -Path $RepoRoot -ChildPath 'Source\Seed\Assignments.psd1'
if (-not (Test-Path $dataFile)) {
    Write-Host "  ERROR: Assignments.psd1 not found at $dataFile"
    exit 1
}

Write-Host "  Seed script: $seedScript"
Write-Host "  Data file: $dataFile"

# Load data file to verify structure
$data = Import-PowerShellDataFile -Path $dataFile -ErrorAction Stop

Write-Host "--- Data file integrity ---"

# A1: Has Assignments array
if ($data.ContainsKey('Assignments') -and $data.Assignments.Count -gt 0) {
    Write-Host "  A1 PASS: Data file has $($data.Assignments.Count) assignments"
} else {
    Write-Host "  A1 FAIL: Missing Assignments array"
}

# A2: Required fields
$missingFields = $false
foreach ($entry in $data.Assignments) {
    if (-not $entry.ContainsKey('groupPath') -or -not $entry.ContainsKey('policyType')) {
        Write-Host "  A2 FAIL: Entry missing required fields"
        $missingFields = $true
        break
    }
}
if (-not $missingFields) { Write-Host "  A2 PASS: All entries have required fields" }

# A3: Count
$count = $data.Assignments.Count
if ($count -ge 20 -and $count -le 30) {
    Write-Host "  A3 PASS: Entry count $count in expected range"
} else {
    Write-Host "  A3 FAIL: Entry count $count outside 20-30 range"
}

# A4: Policy types
$policyTypes = $data.Assignments | ForEach-Object { $_.policyType } | Sort-Object -Unique
if ('exceptions' -in $policyTypes -and 'mem' -in $policyTypes -and 'upgrade' -in $policyTypes -and 'tdad' -in $policyTypes) {
    Write-Host "  A4 PASS: All expected policy types present"
} else {
    Write-Host "  A4 FAIL: Missing policy types"
}

# A5: Fingerprint entries
$fpCount = ($data.Assignments | Where-Object { $_.policyType -eq 'fingerprint' }).Count
if ($fpCount -ge 2) {
    Write-Host "  A5 PASS: $fpCount fingerprint entries"
} else {
    Write-Host "  A5 FAIL: Only $fpCount fingerprint entries (expected >= 2)"
}

Write-Host "=== Smoke complete ==="
