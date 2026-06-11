# Smoke verification for Get-SEPMIpsPolicy (PS5.1)
# Deploy to C:\Users\smokeuser\Desktop\Shared\ via BOM-encoded write, then:
#   python3 Scripts/invoke-winrm.py 'C:\Users\smokeuser\Desktop\Shared\smoke-get-sepmipspolicy.ps1'

[CmdletBinding()]param()

$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"
. "$RepoRoot\Common-PS51.ps1"

Write-Host "=== Smoke: Get-SEPMIpsPolicy (PS5.1) ===" -ForegroundColor Yellow

$pass = 0
$fail = 0

# ── A1: Retrieve IPS policy by name ──
Write-Host "--- A1 : Get-SEPMIpsPolicy by name returns IPS policy ---" -ForegroundColor Cyan
try {
    $r = Get-SEPMIpsPolicy -PolicyName "Intrusion Prevention policy"
    if ($r.name -eq 'Intrusion Prevention policy' -and $null -ne $r.enabled) {
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
