# Smoke verification for Get-SEPMPolicyXML (PS5.1)
# Deploy to C:\Users\smokeuser\Desktop\Shared\ via BOM-encoded write, then:
#   python3 Scripts/invoke-winrm.py 'C:\Users\smokeuser\Desktop\Shared\smoke-get-sepmpolicyxml.ps1'

[CmdletBinding()]param()

$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"
. "$RepoRoot\Common-PS51.ps1"

Write-Host "=== Smoke: Get-SEPMPolicyXML (PS5.1) ===" -ForegroundColor Yellow

$pass = 0
$fail = 0

# ── A1: Retrieve policy XML by name ──
Write-Host "--- A1 : Get-SEPMPolicyXML by name returns XmlDocument ---" -ForegroundColor Cyan
try {
    $r = Get-SEPMPolicyXML -PolicyName "Firewall policy"
    if ($r -is [System.Xml.XmlDocument]) {
        Write-Host "  VERDICT: PASS" -ForegroundColor Green
        $pass++
    } else {
        Write-Host "  VERDICT: FAIL (type: $($r.GetType().FullName))" -ForegroundColor Red
        $fail++
    }
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
    $fail++
}

# ── Summary ──
Write-Host "`n========== SUMMARY (PS5.1) ==========" -ForegroundColor Yellow
Write-Host "TOTAL: $($pass+$fail) tests, $pass pass, $fail fail" -ForegroundColor Yellow
