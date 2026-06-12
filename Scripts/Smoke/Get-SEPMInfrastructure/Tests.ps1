<#
.SYNOPSIS
    Shared smoke tests for infrastructure GET cmdlets.

.DESCRIPTION
    Dot-sourced by run.ps7.ps1 and run.ps51.ps1 after Common.ps1.
    Covers: Get-SEPGUPList, Get-SEPMLicense, Get-SEPMLicense -Summary,
            Get-SEPMDatabaseInfo, Get-SEPMLatestDefinition.
#>

$results = @{}

# ── A1: Get-SEPGUPList ──
$results.A1 = T "A1" "Get-SEPGUPList" `
    { Get-SEPGUPList } `
    { param($r) ($null -eq $r) -or ($r -is [array] -or $r -is [hashtable]) }

# ── A2: Get-SEPMLicense ──
$results.A2 = T "A2" "Get-SEPMLicense" `
    { Get-SEPMLicense } `
    { param($r) $r -ne $null -and ($r -is [PSCustomObject] -or $r -is [hashtable]) }

# ── A3: Get-SEPMLicense -Summary ──
$results.A3 = T "A3" "Get-SEPMLicense -Summary" `
    { Get-SEPMLicense -Summary } `
    { param($r) $r -ne $null -and ($r -is [hashtable]) }

# ── A4: Get-SEPMDatabaseInfo ──
$results.A4 = T "A4" "Get-SEPMDatabaseInfo" `
    { Get-SEPMDatabaseInfo } `
    { param($r) $r -ne $null -and ($r -is [hashtable]) -and $r.database -ne $null -and $r.name -ne $null }

# ── A5: Get-SEPMLatestDefinition ──
$results.A5 = T "A5" "Get-SEPMLatestDefinition" `
    { Get-SEPMLatestDefinition } `
    { param($r) $r -ne $null -and ($r -is [hashtable]) -and $r.contentName -ne $null }

Write-Summary -Results $results -Label "Get-SEPMInfrastructure Smoke Tests"
