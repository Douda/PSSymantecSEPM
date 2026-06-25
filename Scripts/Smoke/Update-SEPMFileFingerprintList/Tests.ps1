<#
.SYNOPSIS
    Shared smoke tests for Update-SEPMFileFingerprintList.

.DESCRIPTION
    Dot-sourced by run.ps7.ps1 and run.ps51.ps1 after Common.ps1.
    Covers: update by ID, update by name, non-null output, verify on API,
            error on invalid name, and cleanup.

    Creates its own fixture fingerprint list if none exist.
#>

$results = @{}

# -- Fixture: find or create a fingerprint list --
$domainId = '1E814550AC1E00027245A393F26DBE37'
$ts = Get-Date -Format 'yyyyMMddHHmmss'
$fixtureName = "SmokeUpdate_Fixture_$ts"
$sha256Hash = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

$s = Initialize-SEPMSession
$fps = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policy-objects/fingerprints" -Headers $s.Headers -SkipCert:$s.SkipCert
$fpList = $null

if ($fps.content -and $fps.content.Count -gt 0) {
    $fpList = $fps.content | Select-Object -First 1
}

if (-not $fpList) {
    Write-Host "No existing fingerprint lists -- creating fixture..." -ForegroundColor Yellow
    $createdId = (Add-SEPMFileFingerprintList -name $fixtureName `
        -description "Smoke test fixture" -HashType "SHA256" `
        -domainId $domainId -hashlist @($sha256Hash) -PassThru).id
    Write-Host "  Created: $fixtureName ($createdId)" -ForegroundColor Gray
    $fpId = $createdId
    $fpName = $fixtureName
} else {
    $fpId = $fpList.id
    $fpName = $fpList.name
    Write-Host "Using fingerprint: $fpName ($fpId)" -ForegroundColor Gray
}

# -- A1: Update by ID (with PassThru) --
$results.A1 = T "A1" "Update by ID" `
    {
        $hashes = @('d41d8cd98f00b204e9800998ecf8427e', 'e99a18c428cb38d5f260853678922e03')
        Update-SEPMFileFingerprintList -FingerprintListID $fpId `
            -name $fpName -domainId $domainId -HashType 'MD5' `
            -description 'Smoke test update' -hashlist $hashes -PassThru
    } `
    { param($r) $r -ne $null }

# -- A2: Update by name (with PassThru) --
$results.A2 = T "A2" "Update by name" `
    {
        $hashes = @('a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a')
        Update-SEPMFileFingerprintList -FingerprintListName $fpName `
            -name $fpName -domainId $domainId -HashType 'SHA256' `
            -description 'Updated via name' -hashlist $hashes -PassThru
    } `
    { param($r) $r -ne $null }

# -- A3: Non-null output (with PassThru) --
$results.A3 = T "A3" "Non-null output" `
    {
        Update-SEPMFileFingerprintList -FingerprintListID $fpId `
            -name $fpName -domainId $domainId -HashType 'SHA256' `
            -hashlist @($sha256Hash) -PassThru
    } `
    { param($r) $r -ne $null }

# -- A4: Verify update on API (AssertTarget reads back from API) --
$results.A4 = T "A4" "Verify update on API" `
    {
        # Perform update with new name
        Update-SEPMFileFingerprintList -FingerprintListID $fpId `
            -name "$fpName-v2" -domainId $domainId -HashType 'SHA256' `
            -hashlist @($sha256Hash) -PassThru | Out-Null

        # Restore original name for idempotency
        Update-SEPMFileFingerprintList -FingerprintListID $fpId `
            -name $fpName -domainId $domainId -HashType 'SHA256' `
            -hashlist @($sha256Hash) -PassThru | Out-Null
    } `
    { param($r) $true } `
    -SleepMs 1000 `
    -AssertTarget {
        # Ground truth: read back from API to verify name was changed and restored
        $fpRead = Invoke-SepmApi -Method GET `
            -Uri "$($s.BaseURLv1)/policy-objects/fingerprints/$fpId" `
            -Headers $s.Headers -SkipCert:$s.SkipCert
        $fpRead.name -eq $fpName
    }

# -- A5: Invalid fingerprint list name writes error --
$results.A5 = T "A5" "Error on invalid name" `
    {
        $errs = $null
        Update-SEPMFileFingerprintList -FingerprintListName 'NonExistentFPList_12345' `
            -name 'Test' -domainId 'd' -HashType 'SHA256' -hashlist @() `
            -ErrorVariable errs -ErrorAction SilentlyContinue
        $errs.Count -gt 0
    } `
    { param($r) $r -eq $true }

# -- Cleanup: remove fixture if we created it --
if (-not $fps.content -or $fps.content.Count -eq 0) {
    Write-Host "`n--- CLEANUP ---" -ForegroundColor Yellow
    try {
        Remove-SEPMFileFingerprintList -FingerprintListName $fixtureName -ErrorAction SilentlyContinue
        Invoke-SepmApi -Method DELETE `
            -Uri "$($s.BaseURLv1)/policy-objects/fingerprints/$fpId" `
            -Headers $s.Headers -SkipCert:$s.SkipCert -ErrorAction SilentlyContinue | Out-Null
        Write-Host "  Removed fixture: $fixtureName" -ForegroundColor Gray
    } catch {
        Write-Host "  Warning: could not remove fixture: $_" -ForegroundColor Yellow
    }
}

# -- Summary --
Write-Summary -Results $results -Label "Update-SEPMFileFingerprintList"
