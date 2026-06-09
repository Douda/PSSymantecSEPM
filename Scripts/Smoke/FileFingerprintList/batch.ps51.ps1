# Smoke verification for file fingerprint list cmdlets (PS5.1)
$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"
. "$RepoRoot\Common-PS51.ps1"

Write-Host "=== Smoke: File Fingerprint Lists (PS5.1) ===" -ForegroundColor Yellow

$domain = Get-SEPMDomain | Where-Object { $_.name -eq 'Default' }
$DOMAIN_ID = $domain.id
Write-Host "Domain: Default ($DOMAIN_ID)" -ForegroundColor Gray

$TEST_LIST_NAME = "SmokeFingerprintTest51"
$HASH1 = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
$HASH2 = 'a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a'

$pass = 0
$fail = 0

# Clean up leftover
try { Remove-SEPMFileFingerprintList -FingerprintListName $TEST_LIST_NAME | Out-Null } catch { }

# A1: Create fingerprint list
Write-Host "--- A1 : Create fingerprint list ---" -ForegroundColor Cyan
try {
    $created = Add-SEPMFileFingerprintList -name $TEST_LIST_NAME -domainId $DOMAIN_ID -HashType 'SHA256' -description 'Smoke test PS51' -hashlist @($HASH1, $HASH2)
    if ($created -and $created.id) {
        Write-Host "  VERDICT: PASS (created: $($created.id))" -ForegroundColor Green
        $LIST_ID = $created.id
        $pass++
    } else {
        Write-Host "  VERDICT: FAIL (no id, result: $created)" -ForegroundColor Red
        $fail++
    }
} catch {
    Write-Host "  VERDICT: FAIL ($($_.Exception.Message))" -ForegroundColor Red
    $fail++
}

# A2: Get by name
Write-Host "--- A2 : Get by name ---" -ForegroundColor Cyan
try {
    $fp = Get-SEPMFileFingerprintList -FingerprintListName $TEST_LIST_NAME
    if ($fp -and $fp.name -eq $TEST_LIST_NAME -and $fp.hashType -eq 'SHA256') {
        Write-Host "  VERDICT: PASS" -ForegroundColor Green
        $pass++
    } else {
        Write-Host "  VERDICT: FAIL (got: $fp)" -ForegroundColor Red
        $fail++
    }
} catch {
    Write-Host "  VERDICT: FAIL ($($_.Exception.Message))" -ForegroundColor Red
    $fail++
}

# A3: Get by ID
Write-Host "--- A3 : Get by ID ---" -ForegroundColor Cyan
try {
    $fpById = Get-SEPMFileFingerprintList -FingerprintListID $LIST_ID
    if ($fpById -and $fpById.id -eq $LIST_ID -and $fpById.name -eq $TEST_LIST_NAME) {
        Write-Host "  VERDICT: PASS" -ForegroundColor Green
        $pass++
    } else {
        Write-Host "  VERDICT: FAIL (got: $fpById)" -ForegroundColor Red
        $fail++
    }
} catch {
    Write-Host "  VERDICT: FAIL ($($_.Exception.Message))" -ForegroundColor Red
    $fail++
}

# A4: Delete by name
Write-Host "--- A4 : Delete by name ---" -ForegroundColor Cyan
try {
    $remResult = Remove-SEPMFileFingerprintList -FingerprintListName $TEST_LIST_NAME
    Write-Host "  Delete result: $($remResult.GetType().FullName) = $remResult"
    Start-Sleep -Seconds 5
    $check = Get-SEPMFileFingerprintList -FingerprintListName $TEST_LIST_NAME
    Write-Host "  Post-check type: $($check.GetType().FullName)"
    # PS5.1 returns raw JSON error string, PS7 returns "Error: ..."
    $isDeleted = ($check -is [string]) -and (($check -like 'Error:*') -or ($check -match '"errorCode"'))
    if ($isDeleted) {
        Write-Host "  VERDICT: PASS (list removed)" -ForegroundColor Green
        $pass++
    } else {
        Write-Host "  VERDICT: FAIL (still exists, check result: $check)" -ForegroundColor Red
        $fail++
    }
} catch {
    Write-Host "  VERDICT: FAIL ($($_.Exception.Message))" -ForegroundColor Red
    $fail++
}

# A5: Delete by ID
Write-Host "--- A5 : Delete by ID ---" -ForegroundColor Cyan
try {
    $created2 = Add-SEPMFileFingerprintList -name 'SmokeFP51_2' -domainId $DOMAIN_ID -HashType 'SHA256' -description 'Del by ID' -hashlist @($HASH1)
    $id2 = $created2.id
    Write-Host "  Created for ID delete: $id2"
    $remResult2 = Remove-SEPMFileFingerprintList -FingerprintListID $id2
    Write-Host "  Delete ID result: $($remResult2.GetType().FullName) = $remResult2"
    Start-Sleep -Seconds 5
    $check2 = Get-SEPMFileFingerprintList -FingerprintListName 'SmokeFP51_2'
    Write-Host "  Post-check type: $($check2.GetType().FullName)"
    $isDeleted2 = ($check2 -is [string]) -and (($check2 -like 'Error:*') -or ($check2 -match '"errorCode"'))
    if ($isDeleted2) {
        Write-Host "  VERDICT: PASS (deleted by ID)" -ForegroundColor Green
        $pass++
    } else {
        Write-Host "  VERDICT: FAIL (still exists, check: $check2)" -ForegroundColor Red
        $fail++
    }
} catch {
    Write-Host "  VERDICT: FAIL ($($_.Exception.Message))" -ForegroundColor Red
    $fail++
}

# ── Summary ──
Write-Host "`n========== SUMMARY (PS5.1) ==========" -ForegroundColor Yellow
Write-Host "TOTAL: $($pass+$fail) tests, $pass pass, $fail fail" -ForegroundColor Yellow

if ($fail -gt 0) { exit 1 }
