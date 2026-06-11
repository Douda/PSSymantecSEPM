# Smoke verification for Get-SEPMExceptionPolicy (PS5.1)
# Deploy to C:\Users\smokeuser\Desktop\Shared\ via BOM-encoded write, then:
#   python3 Scripts/invoke-winrm.py 'C:\Users\smokeuser\Desktop\Shared\smoke-get-sepmexceptionpolicy.ps1'

[CmdletBinding()]param()

$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"
. "$RepoRoot\Common-PS51.ps1"

Write-Host "=== Smoke: Get-SEPMExceptionPolicy (PS5.1) ===" -ForegroundColor Yellow

$pass = 0
$fail = 0

# ── A1: Retrieve exception policy by name ──
Write-Host "--- A1 : Get-SEPMExceptionPolicy by name returns full policy ---" -ForegroundColor Cyan
try {
    $r = Get-SEPMExceptionPolicy -PolicyName "Exceptions policy"
    if ($r.PSObject.TypeNames[0] -eq 'SEPM.ExceptionPolicy' -and $r.name -eq 'Exceptions policy' -and $null -ne $r.configuration) {
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

# ── A2: List files ──
Write-Host "--- A2 : Get-SEPMExceptionPolicy -List files returns flattened files ---" -ForegroundColor Cyan
try {
    $r = Get-SEPMExceptionPolicy -PolicyName "Exceptions policy" -List files
    if ($r -ne $null) {
        Write-Host "  VERDICT: PASS (count: $($r.Count))" -ForegroundColor Green
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
