# Smoke verification for Fingerprints seed (PS 5.1)
# Usage: via WinRM — python3 Scripts/invoke-winrm.py 'C:\Users\smokeuser\Desktop\Shared\smoke-fingerprints.ps1'

$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"
. "$RepoRoot\Common-PS51.ps1"

Write-Host "=== Smoke: Seed Fingerprints (PS5.1) ==="

$seedScript = Join-Path -Path $RepoRoot -ChildPath 'Seed-SEPMData.ps1'
$seedNames = @('Known Malware Hashes', 'Approved Binaries')

# ── Connect ──
$s = Initialize-SEPMSession
$headers = $s.Headers
$skipCert = $s.SkipCert
$baseV1 = $s.BaseURLv1

# ── Clean state ──
foreach ($name in $seedNames) {
    $encodedName = [System.Uri]::EscapeDataString($name)
    $existing = Invoke-SepmApi -Method GET -Uri "$baseV1/policy-objects/fingerprints?name=$encodedName" -Headers $headers -SkipCert:$skipCert
    if ($existing -and $existing.id) {
        $delResp = Invoke-SepmApi -Method DELETE -Uri "$baseV1/policy-objects/fingerprints/$($existing.id)" -Headers $headers -SkipCert:$skipCert
        if ($delResp -is [string] -and $delResp -like 'Error:*') {
            Write-Host "  NOTE: DELETE failed for $name. Will recreate via Force."
        } else {
            Write-Host "  Cleaned up: $name"
        }
    }
}

# ── Verify default domain exists ──
$domains = Invoke-SepmApi -Method GET -Uri "$baseV1/domains" -Headers $headers -SkipCert:$skipCert
$defaultDomainId = $null
foreach ($d in $domains) {
    if ($d.name -eq 'Default') { $defaultDomainId = $d.id; break }
}
Write-Host "Default domain ID: $defaultDomainId"
if (-not $defaultDomainId) { throw "FAIL: could not find Default domain" }

# ── Seed ──
Write-Host "--- Seeding Fingerprints ---"
$result = & $seedScript -Categories Fingerprints 6>&1

$outputText = if ($result -is [array]) { $result -join "`n" } else { $result.ToString() }
if ($outputText -notmatch 'Fingerprints seeded: 2') {
    throw "FAIL: expected 'Fingerprints seeded: 2', got: $outputText"
}

# Re-import module
Import-Module "$RepoRoot\PSSymantecSEPM\PSSymantecSEPM.psm1" -Force
$s = Initialize-SEPMSession
$headers = $s.Headers
$skipCert = $s.SkipCert
$baseV1 = $s.BaseURLv1

# ── Verify Known Malware Hashes ──
Write-Host "--- Verify Known Malware Hashes ---"
$fpHashes = Invoke-SepmApi -Method GET -Uri "$baseV1/policy-objects/fingerprints?name=Known%20Malware%20Hashes" -Headers $headers -SkipCert:$skipCert
if (-not $fpHashes) { throw "FAIL: Known Malware Hashes not found" }
if ($fpHashes.name -ne 'Known Malware Hashes') { throw "FAIL: name mismatch" }
Write-Host "  name: $($fpHashes.name)"
Write-Host "  hashType: $($fpHashes.hashType)"
Write-Host "  description: $($fpHashes.description)"
$hashCount = if ($fpHashes.data) { if ($fpHashes.data.Count) { $fpHashes.data.Count } else { 1 } } else { 0 }
if ($hashCount -ne 5) { throw "FAIL: Known Malware Hashes should have 5 hashes, got $hashCount" }
Write-Host "  hash count: $hashCount PASS"

# Verify hash format
foreach ($hash in $fpHashes.data) {
    if ($hash -is [string] -and $hash.Length -ne 64) {
        throw "FAIL: hash is not 64 chars (length: $($hash.Length))"
    }
    if ($hash -is [string] -and $hash -notmatch '^[0-9a-fA-F]{64}$') {
        throw "FAIL: hash is not valid hex"
    }
}
Write-Host "  all hashes are 64-char hex PASS"

# ── Verify Approved Binaries ──
Write-Host "--- Verify Approved Binaries ---"
$abHashes = Invoke-SepmApi -Method GET -Uri "$baseV1/policy-objects/fingerprints?name=Approved%20Binaries" -Headers $headers -SkipCert:$skipCert
if (-not $abHashes) { throw "FAIL: Approved Binaries not found" }
if ($abHashes.name -ne 'Approved Binaries') { throw "FAIL: name mismatch" }
$hashCount = if ($abHashes.data) { if ($abHashes.data.Count) { $abHashes.data.Count } else { 1 } } else { 0 }
if ($hashCount -ne 3) { throw "FAIL: Approved Binaries should have 3 hashes, got $hashCount" }
Write-Host "  hash count: $hashCount PASS"

foreach ($hash in $abHashes.data) {
    if ($hash -is [string] -and $hash.Length -ne 64) {
        throw "FAIL: hash is not 64 chars (length: $($hash.Length))"
    }
    if ($hash -is [string] -and $hash -notmatch '^[0-9a-fA-F]{64}$') {
        throw "FAIL: hash is not valid hex"
    }
}
Write-Host "  all hashes are 64-char hex PASS"

# ── Idempotency ──
Write-Host "--- Idempotency ---"
$result = & $seedScript -Categories Fingerprints 6>&1
Import-Module "$RepoRoot\PSSymantecSEPM\PSSymantecSEPM.psm1" -Force
$s = Initialize-SEPMSession
$headers = $s.Headers
$skipCert = $s.SkipCert
$baseV1 = $s.BaseURLv1

$outputText = if ($result -is [array]) { $result -join "`n" } else { $result.ToString() }
if ($outputText -notmatch 'Fingerprints seeded: 2') {
    throw "FAIL: idempotent re-run output mismatch: $outputText"
}
Write-Host "  Idempotent: re-run seeded 2 fingerprint lists - PASS"

# ── Force mode ──
Write-Host "--- Force mode ---"
& $seedScript -Categories Fingerprints -Force 6>&1 | Out-Null
Import-Module "$RepoRoot\PSSymantecSEPM\PSSymantecSEPM.psm1" -Force
$s = Initialize-SEPMSession
$headers = $s.Headers
$skipCert = $s.SkipCert
$baseV1 = $s.BaseURLv1

$fpHashes2 = Invoke-SepmApi -Method GET -Uri "$baseV1/policy-objects/fingerprints?name=Known%20Malware%20Hashes" -Headers $headers -SkipCert:$skipCert
$abHashes2 = Invoke-SepmApi -Method GET -Uri "$baseV1/policy-objects/fingerprints?name=Approved%20Binaries" -Headers $headers -SkipCert:$skipCert
if (-not $fpHashes2) { throw "FAIL: Known Malware Hashes missing after Force" }
if (-not $abHashes2) { throw "FAIL: Approved Binaries missing after Force" }
Write-Host "  Force mode: both fingerprint lists recreated - PASS"

Write-Host "`n=== Smoke: Seed Fingerprints (PS5.1) — ALL PASS ===" -ForegroundColor Green
