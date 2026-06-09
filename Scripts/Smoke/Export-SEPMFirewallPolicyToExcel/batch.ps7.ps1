# Smoke verification for Export-SEPMFirewallPolicyToExcel (PS7)
# Usage: pwsh -NoProfile -File Scripts/Smoke/Export-SEPMFirewallPolicyToExcel/batch.ps7.ps1

$ErrorActionPreference = "Continue"
$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"

Write-Host "=== Smoke: Export-SEPMFirewallPolicyToExcel (PS7) ===" -ForegroundColor Yellow

$results = @{}

# ── A1: Standalone mode produces valid XLSX with 3 sheets ──
$xlsxPath = Join-Path -Path $RepoRoot -ChildPath 'Output/smoke-fw.xlsx'
$results.A1 = T "A1" "Standalone: writes 3-sheet XLSX" `
    {
        Remove-Item $xlsxPath -ErrorAction SilentlyContinue
        Export-SEPMFirewallPolicyToExcel -Path $xlsxPath
    } `
    { param($r)
        Test-Path $xlsxPath
    }

# ── A2: Verify 3 sheet names ──
$results.A2 = T "A2" "XLSX has Policies, FirewallRules, PolicyAssignments sheets" `
    { Import-Excel -Path $xlsxPath -WorksheetName 'Policies' | Out-Null; Import-Excel -Path $xlsxPath -WorksheetName 'FirewallRules' | Out-Null; Import-Excel -Path $xlsxPath -WorksheetName 'PolicyAssignments' | Out-Null; $true } `
    { param($r) $r }

# ── A3: Policies sheet has 21 columns ──
$results.A3 = T "A3" "Policies sheet has 21 columns" `
    {
        $sheet = Import-Excel -Path $xlsxPath -WorksheetName 'Policies'
        $sheet[0].PSObject.Properties.Name.Count
    } `
    { param($r) $r -eq 21 }

# ── A4: Policies sheet has data rows ──
$results.A4 = T "A4" "Policies sheet has at least 1 row" `
    {
        $sheet = Import-Excel -Path $xlsxPath -WorksheetName 'Policies'
        $sheet.Count
    } `
    { param($r) $r -gt 0 }

# ── A5: FirewallRules sheet has 19 columns ──
$results.A5 = T "A5" "FirewallRules sheet has 19 columns" `
    {
        $sheet = Import-Excel -Path $xlsxPath -WorksheetName 'FirewallRules'
        $sheet[0].PSObject.Properties.Name.Count
    } `
    { param($r) $r -eq 19 }

# ── A6: FirewallRules has RuleType column with Enforced/Baseline ──
$results.A6 = T "A6" "FirewallRules RuleType values are Enforced or Baseline" `
    {
        $sheet = Import-Excel -Path $xlsxPath -WorksheetName 'FirewallRules'
        $types = $sheet | Select-Object -ExpandProperty RuleType -Unique
        $types -join ','
    } `
    { param($r) $r -match 'Enforced' -and $r -match 'Baseline' }

# ── A7: ConnectionsDetails populated ──
$results.A7 = T "A7" "ConnectionsDetails is non-empty for rules with connections" `
    {
        $sheet = Import-Excel -Path $xlsxPath -WorksheetName 'FirewallRules'
        $withConns = @($sheet | Where-Object { $_.Connections -and $_.Connections -ne '[]' })
        if ($withConns.Count -eq 0) { return "SKIP: no rules with connections" }
        ($withConns | Where-Object { $_.ConnectionsDetails }).Count -gt 0
    } `
    { param($r) $r -eq $true }

# ── A8: Pipeline mode works ──
$snap = Get-SEPMPolicySnapshot -PolicyType fw
$xlsxPath2 = Join-Path -Path $RepoRoot -ChildPath 'Output/smoke-fw-pipe.xlsx'
$results.A8 = T "A8" "Pipeline: accept SEPM.PolicySnapshot" `
    {
        Remove-Item $xlsxPath2 -ErrorAction SilentlyContinue
        $snap | Export-SEPMFirewallPolicyToExcel -Path $xlsxPath2
        Test-Path $xlsxPath2
    } `
    { param($r) $r }

# ── A9: PolicyAssignments sheet has data ──
$results.A9 = T "A9" "PolicyAssignments sheet has at least 1 row" `
    {
        $sheet = Import-Excel -Path $xlsxPath -WorksheetName 'PolicyAssignments'
        $sheet.Count
    } `
    { param($r) $r -gt 0 }

# ── Cleanup ──
Remove-Item $xlsxPath, $xlsxPath2 -ErrorAction SilentlyContinue

# ── Summary ──
Write-Host "`n========== SUMMARY (PS7) ==========" -ForegroundColor Yellow
$pass = 0; $fail = 0; $skip = 0
foreach ($k in $results.Keys | Sort-Object) {
    $v = $results[$k]
    if ($v -eq "PASS") { $pass++; Write-Host "  $k : PASS" -ForegroundColor Green }
    elseif ($v -eq "SKIP") { $skip++; Write-Host "  $k : SKIP" -ForegroundColor Yellow }
    else { $fail++; Write-Host "  $k : FAIL" -ForegroundColor Red }
}
Write-Host "TOTAL: $($pass+$fail+$skip) tests, $pass pass, $fail fail, $skip skip" -ForegroundColor Yellow
