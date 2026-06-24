<#
.SYNOPSIS
    Shared smoke tests for Get-SEPClientInfectedStatus.

.DESCRIPTION
    Dot-sourced by run.ps7.ps1 and run.ps51.ps1 after Common.ps1.
#>

$results = @{}

# ── A1: Get-SEPClientInfectedStatus (no params) returns results ──
$results.A1 = T "A1" "Get-SEPClientInfectedStatus (no params) returns results" `
    { Get-SEPClientInfectedStatus } `
    { param($r) $null -ne $r }

# ── A2: Get-SEPClientInfectedStatus -Clean returns clean computers ──
$results.A2 = T "A2" "Get-SEPClientInfectedStatus -Clean returns clean computers" `
    { Get-SEPClientInfectedStatus -Clean } `
    { param($r) $null -ne $r -and $r.Count -gt 0 }

# ── B1: Get-SEPClientInfectedStatus -ComputerList works ──
$results.B1 = T "B1" "Get-SEPClientInfectedStatus -ComputerList filters from passed list" `
    {
        $all = Get-SEPComputers
        Get-SEPClientInfectedStatus -ComputerList $all
    } `
    { param($r) $null -ne $r }

# ── B2: Get-SEPClientInfectedStatus -ComputerList -Clean works ──
$results.B2 = T "B2" "Get-SEPClientInfectedStatus -ComputerList -Clean filters clean from list" `
    {
        $all = Get-SEPComputers
        Get-SEPClientInfectedStatus -ComputerList $all -Clean
    } `
    { param($r) $null -ne $r -and $r.Count -gt 0 }

# ── Summary ──
Write-Summary -Results $results -Label "Get-SEPClientInfectedStatus"
