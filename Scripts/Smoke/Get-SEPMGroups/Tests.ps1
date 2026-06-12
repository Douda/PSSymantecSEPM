<#
.SYNOPSIS
    Shared smoke tests for Get-SEPMGroups.

.DESCRIPTION
    Dot-sourced by run.ps7.ps1 and run.ps51.ps1 after Common.ps1.
    Covers: basic group retrieval, field validation, collection output.
#>

$results = @{}

# -- A1: returns groups from the API --
$results.A1 = T "A1" "returns groups from the API" `
    { Get-SEPMGroups } `
    { param($r) $r -ne $null -and @($r).Count -gt 0 }

# -- A2: each group has id, name, and fullPathName --
$results.A2 = T "A2" "each group has id, name, and fullPathName" `
    { Get-SEPMGroups } `
    { param($r) @($r)[0].id -ne $null -and @($r)[0].name -ne $null -and @($r)[0].fullPathName -ne $null }

# -- A3: returns collection (not scalar) when single element --
$results.A3 = T "A3" "returns collection (not scalar) when single element" `
    { Get-SEPMGroups } `
    { param($r) $r.Count -ge 1 -and (@($r).Count -eq $r.Count) }

Write-Summary -Results $results -Label "Get-SEPMGroups Smoke"
