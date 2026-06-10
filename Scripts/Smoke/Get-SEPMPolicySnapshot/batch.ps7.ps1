# Smoke verification for Get-SEPMPolicySnapshot (PS7)
# Usage: pwsh -NoProfile -File Scripts/Smoke/Get-SEPMPolicySnapshot/batch.ps7.ps1

[CmdletBinding()]param()

$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"

Write-Host "=== Smoke: Get-SEPMPolicySnapshot (PS7) ===" -ForegroundColor Yellow

$results = @{}

# ── A1: Returns SEPM.PolicySnapshot with FW policies ──
$results.A1 = T "A1" "Get-SEPMPolicySnapshot -PolicyType fw returns SEPM.PolicySnapshot" `
    { Get-SEPMPolicySnapshot -PolicyType fw } `
    { param($r)
        $r -ne $null -and
        $r.PSObject.TypeNames[0] -eq 'SEPM.PolicySnapshot' -and
        $r.FW -ne $null -and
        $r.FW.Policies -ne $null -and
        $r.FW.Policies.Count -gt 0
    }

# ── A2: FW policies have correct type ──
$snap = Get-SEPMPolicySnapshot -PolicyType fw
$results.A2 = T "A2" "FW.Policies items have PSTypeName SEPM.FirewallPolicy" `
    { $snap } `
    { param($r)
        ($r.FW.Policies | ForEach-Object { $_.PSObject.TypeNames[0] } | Select-Object -Unique).Count -eq 1 -and
        $r.FW.Policies[0].PSObject.TypeNames[0] -eq 'SEPM.FirewallPolicy'
    }

# ── A3: FW Summary populated ──
$results.A3 = T "A3" "FW.Summary contains policy summaries" `
    { $snap } `
    { param($r)
        $r.FW.Summary -ne $null -and
        $r.FW.Summary.Count -gt 0 -and
        -not [string]::IsNullOrEmpty($r.FW.Summary[0].name) -and
        $r.FW.Summary[0].PSObject.TypeNames[0] -eq 'SEPM.PolicySummary'
    }

# ── A4: LocationMap has entries ──
$results.A4 = T "A4" "LocationMap is a non-empty hashtable" `
    { $snap } `
    { param($r)
        $r.LocationMap -ne $null -and
        $r.LocationMap.Count -gt 0 -and
        $r.LocationMap -is [hashtable]
    }

# ── A5: FetchedAt is recent ──
$results.A5 = T "A5" "FetchedAt is a DateTime within last 5 minutes" `
    { $snap } `
    { param($r)
        $r.FetchedAt -is [DateTime] -and
        $r.FetchedAt -gt (Get-Date).AddMinutes(-5)
    }

# ── A6: Clixml round-trip ──
$xmlPath = Join-Path -Path $RepoRoot -ChildPath 'Output/snapshot-test.xml'
$results.A6 = T "A6" "Export-Clixml round-trip produces Deserialized.SEPM.PolicySnapshot" `
    {
        $snap | Export-Clixml -Path $xmlPath
        Import-Clixml -Path $xmlPath
        Remove-Item $xmlPath -ErrorAction SilentlyContinue
    } `
    { param($r)
        $ok = $r.PSObject.TypeNames[0] -eq 'Deserialized.SEPM.PolicySnapshot'
        Remove-Item $xmlPath -ErrorAction SilentlyContinue
        $ok
    }

# ── A7: DelayMs honored (smoke: verify default doesn't error) ──
$results.A7 = T "A7" "-DelayMs 100 does not error" `
    { Get-SEPMPolicySnapshot -PolicyType fw -DelayMs 100 } `
    { param($r) $r -ne $null -and $r.FW.Policies.Count -gt 0 }

# ── Summary ──
Write-Host "`n========== SUMMARY (PS7) ==========" -ForegroundColor Yellow
$pass = 0; $fail = 0
foreach ($k in $results.Keys | Sort-Object) {
    $v = $results[$k]
    if ($v -eq "PASS") { $pass++; Write-Host "  $k : PASS" -ForegroundColor Green }
    else { $fail++; Write-Host "  $k : FAIL" -ForegroundColor Red }
}
Write-Host "TOTAL: $($pass+$fail) tests, $pass pass, $fail fail" -ForegroundColor Yellow
