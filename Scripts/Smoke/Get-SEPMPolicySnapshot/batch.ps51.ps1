# Smoke verification for Get-SEPMPolicySnapshot (PS5.1)
# Usage: python3 Scripts/invoke-winrm.py 'C:\Users\smokeuser\Desktop\Shared\smoke-get-sepmPolicySnapshot.ps1'

$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"
. "$RepoRoot\Common-PS51.ps1"

Write-Host "=== Smoke: Get-SEPMPolicySnapshot (PS5.1) ===" -ForegroundColor Yellow

$results = @{}

# ── A1: Returns SEPM.PolicySnapshot with FW policies ──
Write-Host "--- A1 : Get-SEPMPolicySnapshot -PolicyType fw returns SEPM.PolicySnapshot ---" -ForegroundColor Cyan
try {
    $snap = Get-SEPMPolicySnapshot -PolicyType fw
    if ($snap -ne $null -and $snap.PSObject.TypeNames[0] -eq 'SEPM.PolicySnapshot' -and $snap.FW -ne $null -and $snap.FW.Policies.Count -gt 0) {
        Write-Host "  VERDICT: PASS" -ForegroundColor Green
        $results.A1 = "PASS"
    } else {
        Write-Host "  VERDICT: FAIL" -ForegroundColor Red
        $results.A1 = "FAIL"
    }
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
    $results.A1 = "FAIL"
}

# ── A2: FW policies have correct type ──
Write-Host "--- A2 : FW.Policies items have PSTypeName SEPM.FirewallPolicy ---" -ForegroundColor Cyan
try {
    $types = @($snap.FW.Policies | ForEach-Object { $_.PSObject.TypeNames[0] } | Select-Object -Unique)
    if ($types.Count -eq 1 -and $types[0] -eq 'SEPM.FirewallPolicy') {
        Write-Host "  VERDICT: PASS" -ForegroundColor Green
        $results.A2 = "PASS"
    } else {
        Write-Host "  VERDICT: FAIL" -ForegroundColor Red
        $results.A2 = "FAIL"
    }
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
    $results.A2 = "FAIL"
}

# ── A3: FW Summary populated ──
Write-Host "--- A3 : FW.Summary contains policy summaries ---" -ForegroundColor Cyan
try {
    if ($snap.FW.Summary -ne $null -and $snap.FW.Summary.Count -gt 0) {
        Write-Host "  VERDICT: PASS" -ForegroundColor Green
        $results.A3 = "PASS"
    } else {
        Write-Host "  VERDICT: FAIL" -ForegroundColor Red
        $results.A3 = "FAIL"
    }
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
    $results.A3 = "FAIL"
}

# ── A4: LocationMap has entries ──
Write-Host "--- A4 : LocationMap is a non-empty hashtable ---" -ForegroundColor Cyan
try {
    if ($snap.LocationMap -ne $null -and $snap.LocationMap.Count -gt 0) {
        Write-Host "  VERDICT: PASS" -ForegroundColor Green
        $results.A4 = "PASS"
    } else {
        Write-Host "  VERDICT: FAIL" -ForegroundColor Red
        $results.A4 = "FAIL"
    }
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
    $results.A4 = "FAIL"
}

# ── A5: FetchedAt is recent ──
Write-Host "--- A5 : FetchedAt is a DateTime within last 5 minutes ---" -ForegroundColor Cyan
try {
    if ($snap.FetchedAt -gt (Get-Date).AddMinutes(-5)) {
        Write-Host "  VERDICT: PASS" -ForegroundColor Green
        $results.A5 = "PASS"
    } else {
        Write-Host "  VERDICT: FAIL" -ForegroundColor Red
        $results.A5 = "FAIL"
    }
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
    $results.A5 = "FAIL"
}

# ── A6: Clixml round-trip ──
Write-Host "--- A6 : Export-Clixml round-trip produces Deserialized.SEPM.PolicySnapshot ---" -ForegroundColor Cyan
try {
    $xmlPath = "$RepoRoot\snapshot-test.xml"
    $snap | Export-Clixml -Path $xmlPath
    $restored = Import-Clixml -Path $xmlPath
    if ($restored.PSObject.TypeNames[0] -eq 'Deserialized.SEPM.PolicySnapshot') {
        Write-Host "  VERDICT: PASS" -ForegroundColor Green
        $results.A6 = "PASS"
    } else {
        Write-Host "  VERDICT: FAIL" -ForegroundColor Red
        $results.A6 = "FAIL"
    }
    Remove-Item $xmlPath -ErrorAction SilentlyContinue
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Remove-Item $xmlPath -ErrorAction SilentlyContinue
    $results.A6 = "FAIL"
}

# ── A7: DelayMs honored ──
Write-Host "--- A7 : -DelayMs 100 does not error ---" -ForegroundColor Cyan
try {
    $snap2 = Get-SEPMPolicySnapshot -PolicyType fw -DelayMs 100
    if ($snap2 -ne $null -and $snap2.FW.Policies.Count -gt 0) {
        Write-Host "  VERDICT: PASS" -ForegroundColor Green
        $results.A7 = "PASS"
    } else {
        Write-Host "  VERDICT: FAIL" -ForegroundColor Red
        $results.A7 = "FAIL"
    }
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
    $results.A7 = "FAIL"
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
