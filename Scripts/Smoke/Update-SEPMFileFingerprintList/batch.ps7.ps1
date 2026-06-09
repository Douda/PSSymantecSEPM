# Smoke: Update-SEPMFileFingerprintList (PS7)
$ErrorActionPreference = "Continue"
$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"

Write-Host "=== Smoke: Update-SEPMFileFingerprintList (PS7) ==="
$pass = 0; $fail = 0

# Discovery: find or create a fingerprint list
$s = Initialize-SEPMSession
$fps = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policy-objects/fingerprints" -Headers $s.Headers -SkipCert:$s.SkipCert
$fpList = $null

if ($fps.content -and $fps.content.Count -gt 0) {
    $fpList = $fps.content | Select-Object -First 1
    if ($fpList -is [hashtable]) {
        $fpId = $fpList.id
        $fpName = $fpList.name
    } else {
        $fpId = $fpList.id
        $fpName = $fpList.name
    }
} else {
    Write-Host "SKIP: No fingerprint lists available" -ForegroundColor Yellow
    exit 0
}

Write-Host "Using fingerprint: $fpName ($fpId)" -ForegroundColor Gray

# Test 1: Update by ID
try {
    $hashes = @('d41d8cd98f00b204e9800998ecf8427e', 'e99a18c428cb38d5f260853678922e03')
    $result = Update-SEPMFileFingerprintList -FingerprintListID $fpId `
        -name $fpName -domainId '1E814550AC1E00027245A393F26DBE37' `
        -HashType 'MD5' -description 'Smoke test update' -hashlist $hashes
    if ($result) {
        Write-Host "  T1: Update by ID - PASS" -ForegroundColor Green; $pass++
    } else {
        Write-Host "  T1: FAIL" -ForegroundColor Red; $fail++
    }
} catch {
    Write-Host "  T1: FAIL - $($_.Exception.Message)" -ForegroundColor Red; $fail++
}

# Test 2: Update by Name
try {
    $hashes = @('abc123abc123abc123abc123abc123ab')
    $result = Update-SEPMFileFingerprintList -FingerprintListName $fpName `
        -name $fpName -domainId '1E814550AC1E00027245A393F26DBE37' `
        -HashType 'SHA256' -description 'Updated via name' -hashlist $hashes
    if ($result) {
        Write-Host "  T2: Update by name - PASS" -ForegroundColor Green; $pass++
    } else {
        Write-Host "  T2: FAIL" -ForegroundColor Red; $fail++
    }
} catch {
    Write-Host "  T2: FAIL - $($_.Exception.Message)" -ForegroundColor Red; $fail++
}

# Test 3: Non-null output
try {
    $result = Update-SEPMFileFingerprintList -FingerprintListID $fpId `
        -name $fpName -domainId '1E814550AC1E00027245A393F26DBE37' `
        -HashType 'SHA256' -hashlist @('d41d8cd98f00b204e9800998ecf8427e')
    if ($result -ne $null) {
        Write-Host "  T3: Non-null output - PASS" -ForegroundColor Green; $pass++
    } else {
        Write-Host "  T3: FAIL" -ForegroundColor Red; $fail++
    }
} catch {
    Write-Host "  T3: FAIL - $($_.Exception.Message)" -ForegroundColor Red; $fail++
}

# Test 4: Response has id field
try {
    $result = Update-SEPMFileFingerprintList -FingerprintListID $fpId `
        -name "$fpName-v2" -domainId '1E814550AC1E00027245A393F26DBE37' `
        -HashType 'SHA256' -hashlist @('e99a18c428cb38d5f260853678922e03')
    if ($result.id) {
        Write-Host "  T4: Response has id - PASS" -ForegroundColor Green; $pass++
    } else {
        Write-Host "  T4: FAIL" -ForegroundColor Red; $fail++
    }
    # Restore name
    Update-SEPMFileFingerprintList -FingerprintListID $fpId `
        -name $fpName -domainId '1E814550AC1E00027245A393F26DBE37' `
        -HashType 'SHA256' -hashlist @() | Out-Null
} catch {
    Write-Host "  T4: FAIL - $($_.Exception.Message)" -ForegroundColor Red; $fail++
}

# Test 5: Invalid fingerprint list name
try {
    $errors = $null
    Update-SEPMFileFingerprintList -FingerprintListName 'NonExistentFPList_12345' `
        -name 'Test' -domainId 'd' -HashType 'SHA256' -hashlist @() -ErrorVariable errors -ErrorAction SilentlyContinue
    if ($errors.Count -gt 0) {
        Write-Host "  T5: Error on invalid name - PASS" -ForegroundColor Green; $pass++
    } else {
        Write-Host "  T5: FAIL - expected error" -ForegroundColor Red; $fail++
    }
} catch {
    Write-Host "  T5: FAIL - $($_.Exception.Message)" -ForegroundColor Red; $fail++
}

Write-Host "`n=== SUMMARY (PS7) ===" -ForegroundColor Yellow
Write-Host "TOTAL: $($pass+$fail) tests, $pass pass, $fail fail" -ForegroundColor Yellow
if ($fail -gt 0) { exit 1 }
