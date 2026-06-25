<#
.SYNOPSIS
    Shared smoke tests for Get-SEPMComputers.

.DESCRIPTION
    Dot-sourced by run.ps7.ps1 and run.ps51.ps1 after Common.ps1.
#>

$results = @{}

# ── A1: Get-SEPMComputers (no params) returns results ──
$results.A1 = T "A1" "Get-SEPMComputers (no params) returns results" `
    { Get-SEPMComputers } `
    { param($r) $null -ne $r -and $r.Count -gt 0 }

# ── A2: Get-SEPMComputers results have computerName populated ──
$results.A2 = T "A2" "Get-SEPMComputers results have computerName populated" `
    { Get-SEPMComputers } `
    { param($r) $r.Count -gt 0 -and $r[0].computerName.Length -gt 0 }

# ── B1: Get-SEPMComputers -ComputerName filters single computer ──
# Note: uses hardcoded computer name from the VM's seed data to avoid
# scoping issues with variable capture across PS5.1 WinRM sessions.
$results.B1 = T "B1" "Get-SEPMComputers -ComputerName WIN-P093KPK2K7Q" `
    { Get-SEPMComputers -ComputerName 'WIN-P093KPK2K7Q' } `
    { param($r) $r.Count -eq 1 -and $r[0].computerName -eq 'WIN-P093KPK2K7Q' }

# ── Summary ──
Write-Summary -Results $results -Label "Get-SEPMComputers"
