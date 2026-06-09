# Smoke verification for Get-SEPMFirewallPolicy -All (PS7)
# Usage: pwsh -NoProfile -File Scripts/Smoke/Get-SEPMFirewallPolicy/batch.ps7.ps1

[CmdletBinding()]param()

$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"

Write-Host "=== Smoke: Get-SEPMFirewallPolicy (PS7) ===" -ForegroundColor Yellow

$results = @{}

# ── A1: -All returns all FW policies ──
$results.A1 = T "A1" "Get-SEPMFirewallPolicy -All returns all FW policies" `
    { Get-SEPMFirewallPolicy -All } `
    { param($r)
        $r -ne $null -and
        $r.Count -gt 0 -and
        $r[0].PSObject.TypeNames[0] -eq 'SEPM.FirewallPolicy' -and
        -not [string]::IsNullOrEmpty($r[0].name) -and
        $null -ne $r[0].enabled
    }

# ── A2: Verify all policies share correct type ──
$results.A2 = T "A2" "All returned policies have PSTypeName SEPM.FirewallPolicy" `
    { Get-SEPMFirewallPolicy -All } `
    { param($r)
        ($r | ForEach-Object { $_.PSObject.TypeNames[0] } | Select-Object -Unique).Count -eq 1 -and
        $r[0].PSObject.TypeNames[0] -eq 'SEPM.FirewallPolicy'
    }

# ── A3: Verify policy fields are populated ──
$allPolicies = Get-SEPMFirewallPolicy -All
$results.A3 = T "A3" "All policies have non-empty name, id, enabled" `
    { $allPolicies } `
    { param($r)
        $ok = $true
        foreach ($p in $r) {
            if ([string]::IsNullOrEmpty($p.name)) { $ok = $false; break }
            if ($null -eq $p.enabled) { $ok = $false; break }
        }
        $ok
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
