# Smoke verification for Get-SEPMFirewallPolicy -All (PS5.1)
# Deploy to C:\Users\smokeuser\Desktop\Shared\ via BOM-encoded write, then:
#   python3 Scripts/invoke-winrm.py 'C:\Users\smokeuser\Desktop\Shared\smoke-get-sepmfirewallpolicy.ps1'

$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"
. "$RepoRoot\Common-PS51.ps1"

Write-Host "=== Smoke: Get-SEPMFirewallPolicy (PS5.1) ===" -ForegroundColor Yellow

$pass = 0
$fail = 0

# ── A1: -All returns all FW policies ──
Write-Host "--- A1 : Get-SEPMFirewallPolicy -All returns all FW policies ---" -ForegroundColor Cyan
try {
    $r = Get-SEPMFirewallPolicy -All
    if ($r.Count -gt 0 -and $r[0].PSObject.TypeNames[0] -eq 'SEPM.FirewallPolicy' -and $r[0].name) {
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

# ── A2: All policies have correct type ──
Write-Host "--- A2 : All returned policies have PSTypeName SEPM.FirewallPolicy ---" -ForegroundColor Cyan
try {
    $r = Get-SEPMFirewallPolicy -All
    $types = @($r | ForEach-Object { $_.PSObject.TypeNames[0] } | Select-Object -Unique)
    if ($types.Count -eq 1 -and $types[0] -eq 'SEPM.FirewallPolicy') {
        Write-Host "  VERDICT: PASS" -ForegroundColor Green
        $pass++
    } else {
        Write-Host "  VERDICT: FAIL (types: $($types -join ', '))" -ForegroundColor Red
        $fail++
    }
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
    $fail++
}

# ── A3: Policy fields populated ──
Write-Host "--- A3 : All policies have non-empty name, id, enabled ---" -ForegroundColor Cyan
try {
    $r = Get-SEPMFirewallPolicy -All
    $ok = $true
    foreach ($p in $r) {
        if ([string]::IsNullOrEmpty($p.name)) { $ok = $false; break }
        if ($null -eq $p.enabled) { $ok = $false; break }
    }
    if ($ok) {
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
