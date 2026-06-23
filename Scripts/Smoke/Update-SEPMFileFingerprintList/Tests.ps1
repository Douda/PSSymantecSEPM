<#
.SYNOPSIS
    Shared smoke tests for Update-SEPMFileFingerprintList.

.DESCRIPTION
    Dot-sourced by run.ps7.ps1 and run.ps51.ps1 after Common.ps1.
    Covers: update by ID, update by name, non-null output, response has id field,
            error on invalid name, and restores original name.
#>

$results = @{}

# ── Discovery: find a fingerprint list ──
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
}

if (-not $fpList) {
    $results.A1 = Skip "A1" "Update by ID" "No fingerprint lists available"
    $results.A2 = Skip "A2" "Update by name" "No fingerprint lists available"
    $results.A3 = Skip "A3" "Non-null output" "No fingerprint lists available"
    $results.A4 = Skip "A4" "Response has id" "No fingerprint lists available"
    $results.A5 = Skip "A5" "Error on invalid name" "No fingerprint lists for context"
} else {
    Write-Host "Using fingerprint: $fpName ($fpId)" -ForegroundColor Gray
    $domainId = '1E814550AC1E00027245A393F26DBE37'

    # ── A1: Update by ID ──
    $results.A1 = T "A1" "Update by ID" `
        {
            $hashes = @('d41d8cd98f00b204e9800998ecf8427e', 'e99a18c428cb38d5f260853678922e03')
            Update-SEPMFileFingerprintList -FingerprintListID $fpId `
                -name $fpName -domainId $domainId -HashType 'MD5' `
                -description 'Smoke test update' -hashlist $hashes
        } `
        { param($r) $r -ne $null }

    # ── A2: Update by name ──
    $results.A2 = T "A2" "Update by name" `
        {
            $hashes = @('abc123abc123abc123abc123abc123ab')
            Update-SEPMFileFingerprintList -FingerprintListName $fpName `
                -name $fpName -domainId $domainId -HashType 'SHA256' `
                -description 'Updated via name' -hashlist $hashes
        } `
        { param($r) $r -ne $null }

    # ── A3: Non-null output ──
    $results.A3 = T "A3" "Non-null output" `
        {
            Update-SEPMFileFingerprintList -FingerprintListID $fpId `
                -name $fpName -domainId $domainId -HashType 'SHA256' `
                -hashlist @('d41d8cd98f00b204e9800998ecf8427e')
        } `
        { param($r) $r -ne $null }

    # ── A4: Response has id field, then restore name ──
    $results.A4 = T "A4" "Response has id" `
        {
            $r = Update-SEPMFileFingerprintList -FingerprintListID $fpId `
                -name "$fpName-v2" -domainId $domainId -HashType 'SHA256' `
                -hashlist @('e99a18c428cb38d5f260853678922e03')
            $hasId = [bool]$r.id
            Update-SEPMFileFingerprintList -FingerprintListID $fpId `
                -name $fpName -domainId $domainId -HashType 'SHA256' `
                -hashlist @() | Out-Null
            $hasId
        } `
        { param($r) $r -eq $true }

    # ── A5: Invalid fingerprint list name writes error ──
    $results.A5 = T "A5" "Error on invalid name" `
        {
            $errs = $null
            Update-SEPMFileFingerprintList -FingerprintListName 'NonExistentFPList_12345' `
                -name 'Test' -domainId 'd' -HashType 'SHA256' -hashlist @() `
                -ErrorVariable errs -ErrorAction SilentlyContinue
            $errs.Count -gt 0
        } `
        { param($r) $r -eq $true }

    # ── Restore: ensure fingerprint list name is restored (in case A4 was skipped/failed) ──
    Write-Host "`n--- RESTORE ---" -ForegroundColor Yellow
    try {
        Update-SEPMFileFingerprintList -FingerprintListID $fpId `
            -name $fpName -domainId $domainId -HashType 'SHA256' `
            -hashlist @() -ErrorAction SilentlyContinue | Out-Null
        Write-Host "  Fingerprint list name restored: $fpName" -ForegroundColor Gray
    } catch {
        Write-Host "  Warning: could not restore fingerprint list name: $_" -ForegroundColor Yellow
    }
}

# ── Summary ──
Write-Summary -Results $results -Label "Update-SEPMFileFingerprintList"
