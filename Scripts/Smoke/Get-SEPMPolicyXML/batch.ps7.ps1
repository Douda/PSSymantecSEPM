# Smoke verification for Get-SEPMPolicyXML (PS7)
# Usage: pwsh -NoProfile -File Scripts/Smoke/Get-SEPMPolicyXML/batch.ps7.ps1

[CmdletBinding()]param()

$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"

Write-Host "=== Smoke: Get-SEPMPolicyXML (PS7) ===" -ForegroundColor Yellow

$results = @{}

# ── A1: Retrieve policy XML by name ──
$results.A1 = T "A1" "Get-SEPMPolicyXML by name returns XmlDocument" `
    { Get-SEPMPolicyXML -PolicyName "Firewall policy" } `
    { param($r)
        $r -ne $null -and
        $r -is [System.Xml.XmlDocument]
    }

# ── Summary ──
Write-Host "`n========== SUMMARY (PS7) ==========" -ForegroundColor Yellow
$pass = 0; $fail = 0
foreach ($k in $results.Keys | Sort-Object) {
    $v = $results[$k]
    if ($v -eq "PASS") { $pass++; Write-Host "  $k : PASS" -ForegroundColor Green }
    else { $fail++; Write-Host "  $k : FAIL" -ForegroundColor Red }
}
Write-Host "TOTAL: $($pass+$fail) tests, $pass pass, $fail fail" -ForegroundColor Yellow
