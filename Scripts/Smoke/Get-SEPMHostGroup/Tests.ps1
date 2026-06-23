<#
.SYNOPSIS
    Shared smoke tests for Get-SEPMHostGroup.

.DESCRIPTION
    Dot-sourced by run.ps7.ps1 and run.ps51.ps1 after Common.ps1.
    Covers: ById direct fetch, pipeline binding, ByName exact match, ByName wildcard.
#>

$results = @{}

$results.A1 = T "A1" "returns name and hosts by ID" `
    {
        $all = Get-SEPMHostGroupSummary
        Get-SEPMHostGroup -Id $all[0].id
    } `
    { param($r) $r -ne $null -and $r.name -ne $null -and $r.hosts -ne $null }

$results.A2 = Skip "A2" "accepts ID from pipeline" "pipeline binding of hashtable id tested in unit tests"

$results.A3 = T "A3" "resolves by exact name" `
    {
        $all = Get-SEPMHostGroupSummary
        Get-SEPMHostGroup -Name $all[0].name
    } `
    { param($r) $r -ne $null -and $r.name -ne $null }

$results.A4 = T "A4" "resolves by wildcard name" `
    {
        $all = Get-SEPMHostGroupSummary
        $wc = "$($all[0].name.Substring(0, [Math]::Min(3, $all[0].name.Length)))*"
        Get-SEPMHostGroup -Name $wc
    } `
    { param($r) $r -ne $null -and @($r).Count -ge 1 }

Write-Summary -Results $results -Label "Get-SEPMHostGroup Smoke Tests"
