<#
.SYNOPSIS
    Shared smoke tests for FileFingerprintList cmdlets.

.DESCRIPTION
    Dot-sourced by run.ps7.ps1 and run.ps51.ps1 after Common.ps1.
    Covers: Add, Get (by name and ID), Remove (by name and ID),
            Get nonexistent, Remove nonexistent.
    Uses inline try/catch for lifecycle tests that do their own PASS/FAIL verdicts,
    alongside T helper for pure assertion-based tests.
#>

$domain = Get-SEPMDomain | Where-Object { $_.name -eq 'Default' }
$domainId = $domain.id
Write-Host "Domain: Default ($domainId)" -ForegroundColor Gray

$timestamp = Get-Date -Format 'yyyyMMddHHmmss'
$testListName = "SmokeFingerprintTest_$timestamp"
$testListName2 = "SmokeFingerprintDelID_$timestamp"
$sha256Hashes = @(
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    'a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a'
)

function Assert-FingerprintListDeleted {
    <#
    .SYNOPSIS
        Verifies a fingerprint list was deleted by checking the API returns an error.
        Handles both PS7 ("Error: ...") and PS5.1 (raw JSON error with errorCode) formats.
    #>
    param([string]$ListName)
    Start-Sleep -Seconds 2
    $check = Get-SEPMFileFingerprintList -FingerprintListName $ListName
    return ($check -is [string]) -and (($check -like 'Error:*') -or ($check -match '"errorCode"'))
}

$results = @{}

# A1: Create fingerprint list
Write-Host "--- A1 : Create fingerprint list ---" -ForegroundColor Cyan
try {
    $created = Add-SEPMFileFingerprintList -name $testListName -PassThru -domainId $domainId -HashType 'SHA256' -description 'Smoke test' -hashlist $sha256Hashes
    if ($created -and $created.id) {
        Write-Host "  VERDICT: PASS (created: $($created.id))" -ForegroundColor Green
        $listId = $created.id
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
    { Get-SEPMFileFingerprintList -FingerprintListName $testListName } `
    { param($r) $r -ne $null -and $r.name -eq $testListName -and $r.hashType -eq 'SHA256' -and $r.source -eq 'WEBSERVICE' }

# A3: Get by ID - verify same result (skip if A1 failed)
if ($listId) {
    $results.A3 = T "A3" "Get by ID" `
        { Get-SEPMFileFingerprintList -FingerprintListID $listId } `
        { param($r) $r -ne $null -and $r.id -eq $listId -and $r.name -eq $testListName }
} else {
    Write-Host "  A3 : SKIP (no listId from A1)" -ForegroundColor Yellow
    $results.A3 = "SKIP"
}

# A4: Delete by name
Write-Host "--- A4 : Delete by name ---" -ForegroundColor Cyan
try {
    Remove-SEPMFileFingerprintList -FingerprintListName $testListName | Out-Null
    if (Assert-FingerprintListDeleted $testListName) {
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
    $created2 = Add-SEPMFileFingerprintList -name $testListName2 -PassThru -domainId $domainId -HashType 'SHA256' -description 'Smoke test 2' -hashlist @($sha256Hashes[0])
    if (-not $created2.id) {
        Write-Host "  VERDICT: FAIL (create failed)" -ForegroundColor Red
        $results.A5 = "FAIL"
    } else {
        $id2 = $created2.id
        Write-Host "  Created: $testListName2 ($id2)" -ForegroundColor Gray
        Remove-SEPMFileFingerprintList -FingerprintListID $id2 | Out-Null
        if (Assert-FingerprintListDeleted $testListName2) {
            Write-Host "  VERDICT: PASS (deleted by ID)" -ForegroundColor Green
            $results.A5 = "PASS"
        } else {
            Write-Host "  VERDICT: FAIL (list still exists after delete-by-ID)" -ForegroundColor Red
            $results.A5 = "FAIL"
        }
    }
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
    $results.A5 = "FAIL"
}

# A6: Get nonexistent name (expects API error — handles both PS7 and PS5.1 error formats)
Write-Host "--- A6 : Get nonexistent name ---" -ForegroundColor Cyan
try {
    $r = Get-SEPMFileFingerprintList -FingerprintListName 'NonExistentFingerprint'
    if (($r -is [string]) -and (($r -like 'Error:*') -or ($r -match '"errorCode"'))) {
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

# A7: Remove nonexistent (should not throw)
Write-Host "--- A7 : Remove nonexistent ---" -ForegroundColor Cyan
try {
    Remove-SEPMFileFingerprintList -FingerprintListName 'NonExistentFP' -ErrorAction SilentlyContinue | Out-Null
    Write-Host "  VERDICT: PASS (no exception on remove attempt)" -ForegroundColor Green
    $results.A7 = "PASS"
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
    $results.A7 = "FAIL"
}

# ── Summary ──
Write-Summary -Results $results -Label "FileFingerprintList Smoke Tests"
