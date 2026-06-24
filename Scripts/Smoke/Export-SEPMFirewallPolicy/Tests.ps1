<#
.SYNOPSIS
    Shared smoke tests for Export-SEPMFirewallPolicy.

.DESCRIPTION
    Dot-sourced by run.ps7.ps1 and run.ps51.ps1 after Common.ps1.
    Covers: standalone XLSX export with 3 sheets, column counts,
            data presence, pipeline mode, and cleanup.
#>

$results = @{}

# Use temp path for output files (works on both PS7 and PS5.1)
$xlsxPath = Join-Path ([System.IO.Path]::GetTempPath()) 'smoke-fw.xlsx'
$xlsxPath2 = Join-Path ([System.IO.Path]::GetTempPath()) 'smoke-fw-pipe.xlsx'

# ── A1: Standalone mode produces valid XLSX ──
$results.A1 = T "A1" "Standalone: writes XLSX file" `
    {
        Remove-Item $xlsxPath -ErrorAction SilentlyContinue
        Export-SEPMFirewallPolicy -Path $xlsxPath
        Test-Path $xlsxPath
    } `
    { param($r) $r }

# ── A2: Verify 3 sheet names ──
$results.A2 = T "A2" "XLSX has Policies, FirewallRules, PolicyAssignments sheets" `
    {
        $names = Get-ExcelSheetInfo -Path $xlsxPath | Select-Object -ExpandProperty Name
        ($names -join ',')
    } `
    { param($r) $r -match 'Policies' -and $r -match 'FirewallRules' -and $r -match 'PolicyAssignments' }

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
        $types = @($sheet | ForEach-Object { $_.RuleType } | Select-Object -Unique)
        ($types -join ',')
    } `
    { param($r) $r -match 'Enforced' -and $r -match 'Baseline' }

# ── A7: ConnectionsDetails populated (skip if no rules with connections) ──
$firewallSheet = Import-Excel -Path $xlsxPath -WorksheetName 'FirewallRules'
$withConns = @($firewallSheet | Where-Object { $_.Connections -and $_.Connections -ne '[]' })
if ($withConns.Count -eq 0) {
    $results.A7 = Skip "A7" "ConnectionsDetails populated" "No rules with connections"
} else {
    $results.A7 = T "A7" "ConnectionsDetails populated" `
        { ($withConns | Where-Object { $_.ConnectionsDetails }).Count -gt 0 } `
        { param($r) $r -eq $true }
}

# ── A8: Pipeline mode works ──
$snap = Get-SEPMPolicySnapshot -PolicyType fw
$results.A8 = T "A8" "Pipeline: accept SEPM.PolicySnapshot" `
    {
        Remove-Item $xlsxPath2 -ErrorAction SilentlyContinue
        $snap | Export-SEPMFirewallPolicy -Path $xlsxPath2
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
Write-Summary -Results $results -Label "Export-SEPMFirewallPolicy"
