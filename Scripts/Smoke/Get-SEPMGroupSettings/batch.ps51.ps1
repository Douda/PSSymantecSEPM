# Smoke verification for Get-SEPMGroupSettings (PS5.1)
# Deploy to C:\Users\smokeuser\Desktop\Shared\ via BOM-encoded write, then:
#   python3 Scripts/invoke-winrm.py 'C:\Users\smokeuser\Desktop\Shared\smoke-get-sepmgroupsettings.ps1'

[CmdletBinding()]param()

$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"
. "$RepoRoot\Common-PS51.ps1"

Write-Host "=== Smoke: Get-SEPMGroupSettings (PS5.1) ===" -ForegroundColor Yellow

$pass = 0
$fail = 0

$groupId = "1FB75121AC1E0002790C7332FFCDE857"
$locationId = "3BB37557AC1E00020BD263CF8AE23291"

# ── A1: Retrieve group settings ──
Write-Host "--- A1 : Get-SEPMGroupSettings returns settings for group+location ---" -ForegroundColor Cyan
try {
    $r = Get-SEPMGroupSettings -groupId $groupId -locationId $locationId
    if ($r -ne $null) {
        Write-Host "  VERDICT: PASS" -ForegroundColor Green
        $pass++
    } else {
        Write-Host "  VERDICT: FAIL" -ForegroundColor Red
        $fail++
    }
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
    $fail++
}

# ── Summary ──
Write-Host "`n========== SUMMARY (PS5.1) ==========" -ForegroundColor Yellow
Write-Host "TOTAL: $($pass+$fail) tests, $pass pass, $fail fail" -ForegroundColor Yellow
