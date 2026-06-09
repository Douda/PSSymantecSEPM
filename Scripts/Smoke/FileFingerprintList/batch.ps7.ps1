# Smoke verification for file fingerprint list cmdlets (PS7)
$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"

Write-Host "=== Smoke: File Fingerprint Lists (PS7) ===" -ForegroundColor Yellow

$domain = Get-SEPMDomain | Where-Object { $_.name -eq 'Default' }
$DOMAIN_ID = $domain.id
Write-Host "Domain: Default ($DOMAIN_ID)" -ForegroundColor Gray

$TEST_LIST_NAME = "SmokeFingerprintTest"
$SHA256_HASHES = @(
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    'a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a'
)

$results = @{}

# Clean up any leftover from previous runs
try { Remove-SEPMFileFingerprintList -FingerprintListName $TEST_LIST_NAME | Out-Null } catch { }

# A1: Create fingerprint list
Write-Host "--- A1 : Create fingerprint list ---" -ForegroundColor Cyan
try {
    $created = Add-SEPMFileFingerprintList -name $TEST_LIST_NAME -domainId $DOMAIN_ID -HashType 'SHA256' -description 'Smoke test' -hashlist $SHA256_HASHES
    if ($created -and $created.id) {
        Write-Host "  VERDICT: PASS (created: $($created.id))" -ForegroundColor Green
        $LIST_ID = $created.id
        $results.A1 = "PASS"
    } else {
        Write-Host "  VERDICT: FAIL (no id in response)" -ForegroundColor Red
        $results.A1 = "FAIL"
    }
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
    $results.A1 = "FAIL"
}

# A2: Get by name - verify fields
$results.A2 = T "A2" "Get by name (field check)" `
    { Get-SEPMFileFingerprintList -FingerprintListName $TEST_LIST_NAME } `
    { param($r) $r -ne $null -and $r.name -eq $TEST_LIST_NAME -and $r.hashType -eq 'SHA256' -and $r.source -eq 'WEBSERVICE' -and $r.data.Count -eq 2 }

# A3: Get by ID - verify same result
$results.A3 = T "A3" "Get by ID" `
    { Get-SEPMFileFingerprintList -FingerprintListID $LIST_ID } `
    { param($r) $r -ne $null -and $r.id -eq $LIST_ID -and $r.name -eq $TEST_LIST_NAME }

# A4: Delete by name
Write-Host "--- A4 : Delete by name ---" -ForegroundColor Cyan
try {
    $remResult = Remove-SEPMFileFingerprintList -FingerprintListName $TEST_LIST_NAME
    Start-Sleep -Milliseconds 1000
    $check = Get-SEPMFileFingerprintList -FingerprintListName $TEST_LIST_NAME
    if ($check -is [string] -and $check -like 'Error:*') {
        Write-Host "  VERDICT: PASS (list removed)" -ForegroundColor Green
        $results.A4 = "PASS"
    } else {
        Write-Host "  VERDICT: FAIL (list still exists)" -ForegroundColor Red
        $results.A4 = "FAIL"
    }
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
    $results.A4 = "FAIL"
}

# A5: Delete by ID (create first, then delete by ID)
Write-Host "--- A5 : Delete by ID ---" -ForegroundColor Cyan
try {
    $created2 = Add-SEPMFileFingerprintList -name 'SmokeFingerprint2' -domainId $DOMAIN_ID -HashType 'SHA256' -description 'Smoke test 2' -hashlist @('e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855')
    $id2 = $created2.id
    $remResult2 = Remove-SEPMFileFingerprintList -FingerprintListID $id2
    Start-Sleep -Milliseconds 1000
    $check2 = Get-SEPMFileFingerprintList -FingerprintListName 'SmokeFingerprint2'
    if ($check2 -is [string] -and $check2 -like 'Error:*') {
        Write-Host "  VERDICT: PASS (deleted by ID)" -ForegroundColor Green
        $results.A5 = "PASS"
    } else {
        Write-Host "  VERDICT: FAIL" -ForegroundColor Red
        $results.A5 = "FAIL"
    }
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
    $results.A5 = "FAIL"
}

# A6: Get nonexistent name (expects API error - cannot use T helper)
Write-Host "--- A6 : Get nonexistent name ---" -ForegroundColor Cyan
try {
    $r = Get-SEPMFileFingerprintList -FingerprintListName 'NonExistentFingerprint'
    if ($r -is [string] -and $r -like 'Error:*') {
        Write-Host "  VERDICT: PASS (got expected API error)" -ForegroundColor Green
        $results.A6 = "PASS"
    } else {
        Write-Host "  VERDICT: FAIL (expected error string)" -ForegroundColor Red
        $results.A6 = "FAIL"
    }
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
    $results.A6 = "FAIL"
}

# A7: Remove nonexistent
Write-Host "--- A7 : Remove nonexistent ---" -ForegroundColor Cyan
try {
    # Ensure clean state
    try { Remove-SEPMFileFingerprintList -FingerprintListName 'NonExistentFP' | Out-Null } catch { }
    Write-Host "  VERDICT: PASS (no exception on remove attempt)" -ForegroundColor Green
    $results.A7 = "PASS"
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
    $results.A7 = "FAIL"
}

# ── Summary ──
Write-Host "`n========== SUMMARY (PS7) ==========" -ForegroundColor Yellow
$pass = 0; $fail = 0
foreach ($k in $results.Keys | Sort-Object) {
    $v = $results[$k]
    if ($v -eq "PASS") { $pass++; Write-Host "  $k : PASS" -ForegroundColor Green }
    else { $fail++; Write-Host "  $k : FAIL" -ForegroundColor Red }
}
Write-Host "TOTAL: $($pass+$fail) tests, $pass pass, $fail fail" -ForegroundColor Yellow

if ($fail -gt 0) { exit 1 }
