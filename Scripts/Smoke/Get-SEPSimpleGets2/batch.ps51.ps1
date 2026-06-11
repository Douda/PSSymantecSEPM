# Smoke batch: simple GET cmdlets batch 2 (PS5.1)
# Covers: Get-SEPMAdmins, Get-SEPMDomain, Get-SEPClientStatus,
#         Get-SEPClientVersion, Get-SEPClientDefVersions,
#         Get-SEPMReplicationStatus, Get-SEPMThreatStats
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File C:\Users\smokeuser\Desktop\Shared\smoke-simplegets2.ps1

$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"
. "$RepoRoot\Common-PS51.ps1"

Write-Host "=== Smoke: Simple GETs Batch 2 (PS5.1) ==="

$results = @{}

# ── A1: Get-SEPMAdmins ──
try {
    $r = Get-SEPMAdmins
    if ($r -is [array] -and $r.Count -gt 0 -and $r[0].loginName -ne $null) { $results.A1 = "PASS" } else { $results.A1 = "FAIL" }
} catch { Write-Host "ERROR: $_" -ForegroundColor Red; $results.A1 = "FAIL" }
Write-Host "A1: Get-SEPMAdmins => $($results.A1)"

# ── B1: Get-SEPMDomain ──
try {
    $r = Get-SEPMDomain
    if ($r -ne $null -and $r.id -ne $null) { $results.B1 = "PASS" } else { $results.B1 = "FAIL" }
} catch { Write-Host "ERROR: $_" -ForegroundColor Red; $results.B1 = "FAIL" }
Write-Host "B1: Get-SEPMDomain => $($results.B1)"

# ── C1: Get-SEPClientStatus ──
try {
    $r = Get-SEPClientStatus
    if ($r -is [array] -and $r.Count -gt 0 -and $r[0].status -ne $null) { $results.C1 = "PASS" } else { $results.C1 = "FAIL" }
} catch { Write-Host "ERROR: $_" -ForegroundColor Red; $results.C1 = "FAIL" }
Write-Host "C1: Get-SEPClientStatus => $($results.C1)"

# ── D1: Get-SEPClientVersion ──
try {
    $r = Get-SEPClientVersion
    if ($r -is [array] -and $r.Count -gt 0 -and $r[0].version -ne $null) { $results.D1 = "PASS" } else { $results.D1 = "FAIL" }
} catch { Write-Host "ERROR: $_" -ForegroundColor Red; $results.D1 = "FAIL" }
Write-Host "D1: Get-SEPClientVersion => $($results.D1)"

# ── E1: Get-SEPClientDefVersions ──
try {
    $r = Get-SEPClientDefVersions
    if ($r -is [array] -and $r.Count -gt 0 -and $r[0].version -ne $null) { $results.E1 = "PASS" } else { $results.E1 = "FAIL" }
} catch { Write-Host "ERROR: $_" -ForegroundColor Red; $results.E1 = "FAIL" }
Write-Host "E1: Get-SEPClientDefVersions => $($results.E1)"

# ── F1: Get-SEPMReplicationStatus ──
try {
    $r = Get-SEPMReplicationStatus
    # PS5.1: hashtable dot-notation may not unwrap; check Count and keys
if ($r.Count -gt 0) { $results.F1 = "PASS" } else { $results.F1 = "FAIL" }
} catch { Write-Host "ERROR: $_" -ForegroundColor Red; $results.F1 = "FAIL" }
Write-Host "F1: Get-SEPMReplicationStatus => $($results.F1)"

# ── G1: Get-SEPMThreatStats ──
try {
    $r = Get-SEPMThreatStats
    if ($r -ne $null -and $r.lastUpdated -ne $null) { $results.G1 = "PASS" } else { $results.G1 = "FAIL" }
} catch { Write-Host "ERROR: $_" -ForegroundColor Red; $results.G1 = "FAIL" }
Write-Host "G1: Get-SEPMThreatStats => $($results.G1)"

# ── Summary ──
$pass = 0; $fail = 0
foreach ($k in $results.Keys | Sort-Object) {
    if ($results[$k] -eq "PASS") { $pass++ } else { $fail++ }
}
Write-Host "TOTAL: $($results.Count) tests, $pass pass, $fail fail"

if ($fail -gt 0) { exit 1 }
