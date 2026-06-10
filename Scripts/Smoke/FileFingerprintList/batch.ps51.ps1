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

function T {
    <#
    .SYNOPSIS
        Standard smoke test runner for GET cmdlets.
    #>
    param($Id, $Label, [ScriptBlock]$Action, [ScriptBlock]$Assert)
    Write-Host "--- $Id : $Label ---" -ForegroundColor Cyan
    try {
        $result = & $Action

        if ($result -is [string] -and $result -like "Error:*") {
            Write-Host "  VERDICT: FAIL (API error: $result)" -ForegroundColor Red
            return "FAIL"
        }

        $ok = & $Assert $result
        if ($ok) { Write-Host "  VERDICT: PASS" -ForegroundColor Green; return "PASS" }
        else     { Write-Host "  VERDICT: FAIL" -ForegroundColor Red;   return "FAIL" }
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        return "FAIL"
    }
}

function Assert-FingerprintListDeleted {
    <#
    .SYNOPSIS
        Verifies a fingerprint list was deleted by checking the API returns an error.
    #>
    param([string]$ListName)
    Start-Sleep -Seconds 2
    $check = Get-SEPMFileFingerprintList -FingerprintListName $ListName
    # PS5.1 returns raw JSON error string, PS7 returns "Error: ..."
    return ($check -is [string]) -and (($check -like 'Error:*') -or ($check -match '"errorCode"'))
}

$results = @{}

# Clean up leftover
try { Remove-SEPMFileFingerprintList -FingerprintListName $TEST_LIST_NAME | Out-Null } catch { }

# A1: Create fingerprint list
Write-Host "--- A1 : Create fingerprint list ---" -ForegroundColor Cyan
try {
    $created = Add-SEPMFileFingerprintList -name $TEST_LIST_NAME -domainId $DOMAIN_ID -HashType 'SHA256' -description 'Smoke test PS51' -hashlist @($HASH1, $HASH2)
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

# A2: Get by name and verify fields
$results.A2 = T "A2" "Get by name (field check)" `
    { Get-SEPMFileFingerprintList -FingerprintListName $TEST_LIST_NAME } `
    { param($r) $r -ne $null -and $r.name -eq $TEST_LIST_NAME -and $r.hashType -eq 'SHA256' }

# A3: Get by ID
$results.A3 = T "A3" "Get by ID" `
    { Get-SEPMFileFingerprintList -FingerprintListID $LIST_ID } `
    { param($r) $r -ne $null -and $r.id -eq $LIST_ID -and $r.name -eq $TEST_LIST_NAME }

# A4: Delete by name
Write-Host "--- A4 : Delete by name ---" -ForegroundColor Cyan
try {
    Remove-SEPMFileFingerprintList -FingerprintListName $TEST_LIST_NAME | Out-Null
    if (Assert-FingerprintListDeleted $TEST_LIST_NAME) {
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
    $created2 = Add-SEPMFileFingerprintList -name 'SmokeFP51_2' -domainId $DOMAIN_ID -HashType 'SHA256' -description 'Del by ID' -hashlist @($HASH1)
    $id2 = $created2.id
    Remove-SEPMFileFingerprintList -FingerprintListID $id2 | Out-Null
    if (Assert-FingerprintListDeleted 'SmokeFP51_2') {
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

# ── Summary ──
Write-Host "`n========== SUMMARY (PS5.1) ==========" -ForegroundColor Yellow
$pass = 0; $fail = 0
foreach ($k in $results.Keys | Sort-Object) {
    $v = $results[$k]
    if ($v -eq "PASS") { $pass++; Write-Host "  $k : PASS" -ForegroundColor Green }
    else { $fail++; Write-Host "  $k : FAIL" -ForegroundColor Red }
}
Write-Host "TOTAL: $($pass+$fail) tests, $pass pass, $fail fail" -ForegroundColor Yellow

if ($fail -gt 0) { exit 1 }
