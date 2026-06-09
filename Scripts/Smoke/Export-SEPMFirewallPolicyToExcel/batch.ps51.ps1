[CmdletBinding()]param()

$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"
. "$RepoRoot\Common-PS51.ps1"

Write-Host "=== Smoke: Export-SEPMFirewallPolicyToExcel (PS5.1) ===" -ForegroundColor Yellow

function T {
    param($Id, $Label, [ScriptBlock]$Action, [ScriptBlock]$Assert)
    Write-Host "--- $Id : $Label ---" -ForegroundColor Cyan
    try {
        $result = & $Action
        if ($result -is [string] -and $result -like "Error:*") {
            Write-Host "  VERDICT: FAIL (API error: $result)" -ForegroundColor Red
            return "FAIL"
        }
        $ok = & $Assert $result
        if ($ok) { Write-Host "  VERDICT: PASS" -ForegroundColor Green; return "PASS" }
        else     { Write-Host "  VERDICT: FAIL" -ForegroundColor Red;   return "FAIL" }
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        return "FAIL"
    }
}

$results = @{}

$xlsxPath = "$RepoRoot\smoke-fw-ps51.xlsx"

# A1: Standalone mode
$results.A1 = T "A1" "Standalone: writes 3-sheet XLSX" `
    {
        if (Test-Path $xlsxPath) { Remove-Item $xlsxPath -Force }
        Export-SEPMFirewallPolicyToExcel -Path $xlsxPath
        Test-Path $xlsxPath
    } `
    { param($r) $r }

# A2: Verify sheets
$results.A2 = T "A2" "XLSX has 3 sheets" `
    {
        $names = Get-ExcelSheetInfo -Path $xlsxPath | Select-Object -ExpandProperty Name
        ($names -join ',')
    } `
    { param($r) $r -match 'Policies' -and $r -match 'FirewallRules' -and $r -match 'PolicyAssignments' }

# A3: Policies sheet columns
$results.A3 = T "A3" "Policies sheet has 21 columns" `
    {
        $sheet = Import-Excel -Path $xlsxPath -WorksheetName 'Policies'
        $sheet[0].PSObject.Properties.Name.Count
    } `
    { param($r) $r -eq 21 }

# A4: Policies has data
$results.A4 = T "A4" "Policies sheet has rows" `
    {
        $sheet = Import-Excel -Path $xlsxPath -WorksheetName 'Policies'
        $sheet.Count
    } `
    { param($r) $r -gt 0 }

# A5: FirewallRules columns
$results.A5 = T "A5" "FirewallRules sheet has 19 columns" `
    {
        $sheet = Import-Excel -Path $xlsxPath -WorksheetName 'FirewallRules'
        $sheet[0].PSObject.Properties.Name.Count
    } `
    { param($r) $r -eq 19 }

# A6: RuleType values
$results.A6 = T "A6" "FirewallRules has Enforced and Baseline types" `
    {
        $sheet = Import-Excel -Path $xlsxPath -WorksheetName 'FirewallRules'
        $types = @($sheet | ForEach-Object { $_.RuleType } | Select-Object -Unique)
        ($types -join ',')
    } `
    { param($r) $r -match 'Enforced' -and $r -match 'Baseline' }

# A7: Pipeline mode
$snap = Get-SEPMPolicySnapshot -PolicyType fw
$xlsxPath2 = "$RepoRoot\smoke-fw-pipe-ps51.xlsx"
$results.A7 = T "A7" "Pipeline: accept SEPM.PolicySnapshot" `
    {
        if (Test-Path $xlsxPath2) { Remove-Item $xlsxPath2 -Force }
        $snap | Export-SEPMFirewallPolicyToExcel -Path $xlsxPath2
        Test-Path $xlsxPath2
    } `
    { param($r) $r }

# A8: PolicyAssignments
$results.A8 = T "A8" "PolicyAssignments sheet has rows" `
    {
        $sheet = Import-Excel -Path $xlsxPath -WorksheetName 'PolicyAssignments'
        $sheet.Count
    } `
    { param($r) $r -gt 0 }

# Cleanup
Remove-Item $xlsxPath, $xlsxPath2 -Force -ErrorAction SilentlyContinue

Write-Host "`n========== SUMMARY (PS5.1) ==========" -ForegroundColor Yellow
$pass = 0; $fail = 0; $skip = 0
foreach ($k in $results.Keys | Sort-Object) {
    $v = $results[$k]
    if ($v -eq "PASS") { $pass++; Write-Host "  $k : PASS" -ForegroundColor Green }
    elseif ($v -eq "SKIP") { $skip++; Write-Host "  $k : SKIP" -ForegroundColor Yellow }
    else { $fail++; Write-Host "  $k : FAIL" -ForegroundColor Red }
}
Write-Host "TOTAL: $($pass+$fail+$skip) tests, $pass pass, $fail fail, $skip skip" -ForegroundColor Yellow
