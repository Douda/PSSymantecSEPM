<#
.SYNOPSIS
    Shared smoke tests for Seed-Fingerprints.

.DESCRIPTION
    Dot-sourced by run.ps7.ps1 and run.ps51.ps1 after Common.ps1.
    Cleans old fingerprint lists, seeds 2 lists, verifies config details,
    and tests idempotency and force mode.
#>

Write-Host "=== Smoke: Seed Fingerprints ==="

# ── Private function wrappers (module-scope tunnel) ──
$script:__SepmModule = Get-Module PSSymantecSEPM

function Invoke-SepmApi {
    & $script:__SepmModule { Invoke-SepmApi @args } @args
}
function Initialize-SEPMSession {
    & $script:__SepmModule { Initialize-SEPMSession @args } @args
}

$seedScript = Join-Path -Path $RepoRoot -ChildPath 'Scripts/Seed-SEPMData.ps1'
$seedNames = @('Known Malware Hashes', 'Approved Binaries')

# ── Clean state: delete existing seed fingerprint lists if any ──
$s = Initialize-SEPMSession
foreach ($name in $seedNames) {
    $existing = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policy-objects/fingerprints?name=$([System.Uri]::EscapeDataString($name))" -Headers $s.Headers -SkipCert:$s.SkipCert
    if ($existing -and $existing.id) {
        $delResp = Invoke-SepmApi -Method DELETE -Uri "$($s.BaseURLv1)/policy-objects/fingerprints/$($existing.id)" -Headers $s.Headers -SkipCert:$s.SkipCert
        if ($delResp -is [string] -and $delResp -like 'Error:*') {
            Write-Host "  NOTE: DELETE failed for $name (API limitation). Will recreate via Force."
        } else {
            Write-Host "  Cleaned up: $name"
        }
    }
}

# ── Get default domain ID ──
$s = Initialize-SEPMSession
$domains = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/domains" -Headers $s.Headers -SkipCert:$s.SkipCert
$defaultDomainId = ($domains | Where-Object { $_.name -eq 'Default' } | Select-Object -First 1).id
Write-Host "Default domain ID: $defaultDomainId"

$results = @{}

# ── A1: Default domain exists ──
$results.A1 = & {
    if ($defaultDomainId) {
        Write-Host "  VERDICT: PASS" -ForegroundColor Green
        "PASS"
    } else {
        Write-Host "  ERROR: could not find Default domain" -ForegroundColor Red
        "FAIL"
    }
}

# ── A2: Seed output ──
$results.A2 = & {
    try {
        $result = & $seedScript -Categories Fingerprints 6>&1
        $outputText = if ($result -is [array]) { $result -join "`n" } else { $result.ToString() }
        if ($outputText -notmatch 'Fingerprints seeded: 2') {
            throw "expected 'Fingerprints seeded: 2', got: $outputText"
        }
        Write-Host "  VERDICT: PASS" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── A3: Verify Known Malware Hashes exists with correct count ──
$results.A3 = & {
    try {
        $s = Initialize-SEPMSession
        $fpHashes = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policy-objects/fingerprints?name=Known%20Malware%20Hashes" -Headers $s.Headers -SkipCert:$s.SkipCert
        if (-not $fpHashes) { throw "Known Malware Hashes not found" }
        if ($fpHashes.name -ne 'Known Malware Hashes') { throw "name mismatch: $($fpHashes.name)" }
        Write-Host "  name: $($fpHashes.name)"
        Write-Host "  hashType: $($fpHashes.hashType)"
        Write-Host "  description: $($fpHashes.description)"
        $hashCount = if ($fpHashes.data) { if ($fpHashes.data.Count) { $fpHashes.data.Count } else { 1 } } else { 0 }
        if ($hashCount -ne 5) { throw "Known Malware Hashes should have 5 hashes, got $hashCount" }
        Write-Host "  hash count: $hashCount PASS" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── A4: Known Malware Hashes hash format ──
$results.A4 = & {
    try {
        $s = Initialize-SEPMSession
        $fpHashes = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policy-objects/fingerprints?name=Known%20Malware%20Hashes" -Headers $s.Headers -SkipCert:$s.SkipCert
        foreach ($hash in $fpHashes.data) {
            if ($hash -is [string] -and $hash.Length -ne 64) {
                throw "hash is not 64 chars (length: $($hash.Length))"
            }
            if ($hash -is [string] -and $hash -notmatch '^[0-9a-fA-F]{64}$') {
                throw "hash is not valid hex"
            }
        }
        Write-Host "  all hashes are 64-char hex PASS" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── A5: Verify Approved Binaries exists with correct count ──
$results.A5 = & {
    try {
        $s = Initialize-SEPMSession
        $abHashes = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policy-objects/fingerprints?name=Approved%20Binaries" -Headers $s.Headers -SkipCert:$s.SkipCert
        if (-not $abHashes) { throw "Approved Binaries not found" }
        if ($abHashes.name -ne 'Approved Binaries') { throw "name mismatch: $($abHashes.name)" }
        $hashCount = if ($abHashes.data) { if ($abHashes.data.Count) { $abHashes.data.Count } else { 1 } } else { 0 }
        if ($hashCount -ne 3) { throw "Approved Binaries should have 3 hashes, got $hashCount" }
        Write-Host "  hash count: $hashCount PASS" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── A6: Approved Binaries hash format ──
$results.A6 = & {
    try {
        $s = Initialize-SEPMSession
        $abHashes = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policy-objects/fingerprints?name=Approved%20Binaries" -Headers $s.Headers -SkipCert:$s.SkipCert
        foreach ($hash in $abHashes.data) {
            if ($hash -is [string] -and $hash.Length -ne 64) {
                throw "hash is not 64 chars (length: $($hash.Length))"
            }
            if ($hash -is [string] -and $hash -notmatch '^[0-9a-fA-F]{64}$') {
                throw "hash is not valid hex"
            }
        }
        Write-Host "  all hashes are 64-char hex PASS" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── A7: Idempotency ──
$results.A7 = & {
    try {
        Write-Host "--- Idempotency ---"
        $idemResult = & $seedScript -Categories Fingerprints 6>&1
        $outputText = if ($idemResult -is [array]) { $idemResult -join "`n" } else { $idemResult.ToString() }
        if ($outputText -notmatch 'Fingerprints seeded: 2') {
            throw "idempotent re-run output mismatch: $outputText"
        }
        Write-Host "  Idempotent: re-run seeded 2 fingerprint lists - PASS" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── A8: Force mode ──
$results.A8 = & {
    try {
        Write-Host "--- Force mode ---"
        & $seedScript -Categories Fingerprints -Force 6>&1 | Out-Null
        $s = Initialize-SEPMSession
        $fpHashes2 = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policy-objects/fingerprints?name=Known%20Malware%20Hashes" -Headers $s.Headers -SkipCert:$s.SkipCert
        $abHashes2 = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policy-objects/fingerprints?name=Approved%20Binaries" -Headers $s.Headers -SkipCert:$s.SkipCert
        if (-not $fpHashes2) { throw "Known Malware Hashes missing after Force" }
        if (-not $abHashes2) { throw "Approved Binaries missing after Force" }
        Write-Host "  Force mode: both fingerprint lists recreated - PASS" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── Summary ──
Write-Summary -Results $results -Label "Seed Fingerprints Smoke Tests"
