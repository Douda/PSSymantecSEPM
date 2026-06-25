<#
.SYNOPSIS
    Shared smoke tests for Get-SEPMClientInfectedStatus.

.DESCRIPTION
    Dot-sourced by run.ps7.ps1 and run.ps51.ps1 after Common.ps1.
#>

$results = @{}

# ── A1: Get-SEPMClientInfectedStatus (no params) returns results ──
$results.A1 = T "A1" "Get-SEPMClientInfectedStatus (no params) returns results" `
    { Get-SEPMClientInfectedStatus } `
    { param($r) $null -ne $r }

# ── A2: Get-SEPMClientInfectedStatus -Clean returns clean computers ──
$results.A2 = T "A2" "Get-SEPMClientInfectedStatus -Clean returns clean computers" `
    { Get-SEPMClientInfectedStatus -Clean } `
    { param($r) $null -ne $r -and $r.Count -gt 0 }

# ── B1: Get-SEPMClientInfectedStatus -ComputerList works ──
$results.B1 = T "B1" "Get-SEPMClientInfectedStatus -ComputerList filters from passed list" `
    {
        $all = Get-SEPMComputers
        Get-SEPMClientInfectedStatus -ComputerList $all
    } `
    { param($r) $null -ne $r }

# ── B2: Get-SEPMClientInfectedStatus -ComputerList -Clean works ──
$results.B2 = T "B2" "Get-SEPMClientInfectedStatus -ComputerList -Clean filters clean from list" `
    {
        $all = Get-SEPMComputers
        Get-SEPMClientInfectedStatus -ComputerList $all -Clean
    } `
    { param($r) $null -ne $r -and $r.Count -gt 0 }

# ── Summary ──
Write-Summary -Results $results -Label "Get-SEPMClientInfectedStatus"
