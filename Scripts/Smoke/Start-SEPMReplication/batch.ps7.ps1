# Smoke: Start-SEPMReplication (PS7)
# Usage: pwsh -NoProfile -File Scripts/Smoke/Start-SEPMReplication/batch.ps7.ps1

$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"

Write-Host "=== Smoke: Start-SEPMReplication (PS7) ===" -ForegroundColor Yellow

$results = @{}

# ── A1: Send with partner site name (null/error both acceptable) ──
$results.A1 = T "A1" "Send with partner" `
    {
        try {
            Start-SEPMReplication -partnerSiteName 'RemoteSiteTest' | Out-Null
            $true
        } catch {
            $msg = $_.Exception.Message
            $msg -match 'partner|site|replication|not found'
        }
    } `
    { param($r) $r -eq $true }

# ── A2: Call without parameters (null acceptable) ──
$results.A2 = T "A2" "No-param call" `
    { Start-SEPMReplication | Out-Null; $true } `
    { param($r) $r -eq $true }

# === Summary ===
Write-Host "`n========== SUMMARY (PS7) ==========" -ForegroundColor Yellow
$pass = 0; $fail = 0; $skip = 0
foreach ($k in $results.Keys | Sort-Object) {
    $v = $results[$k]
    if ($v -eq "PASS") { $pass++; Write-Host "  $k : PASS" -ForegroundColor Green }
    elseif ($v -eq "SKIP") { $skip++; Write-Host "  $k : SKIP" -ForegroundColor Yellow }
    else { $fail++; Write-Host "  $k : FAIL" -ForegroundColor Red }
}
Write-Host "TOTAL: $($pass+$fail+$skip) tests, $pass pass, $fail fail, $skip skip" -ForegroundColor Yellow

if ($fail -gt 0) { exit 1 }
