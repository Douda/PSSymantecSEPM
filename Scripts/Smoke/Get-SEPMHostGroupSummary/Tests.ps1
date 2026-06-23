<#
.SYNOPSIS
    Shared smoke tests for Get-SEPMHostGroupSummary.

.DESCRIPTION
    Dot-sourced by run.ps7.ps1 and run.ps51.ps1 after Common.ps1.
    Covers: basic retrieval, field structure, DomainId scoping.
#>

$results = @{}

$results.A1 = T "A1" "returns host group summaries" `
    { Get-SEPMHostGroupSummary } `
    { param($r) $r -ne $null -and $r.Count -gt 0 }

$results.A2 = T "A2" "each summary has id, name, domainid, lastmodifiedtime" `
    { Get-SEPMHostGroupSummary | Select-Object -First 1 } `
    { param($r) $r.id -ne $null -and $r.name -ne $null -and $r.domainid -ne $null -and $r.lastmodifiedtime -ne $null }

$results.A3 = T "A3" "accepts -DomainId and returns scoped results" `
    { Get-SEPMHostGroupSummary -DomainId (Get-SEPMDomain | Select-Object -First 1).id } `
    { param($r) $r -ne $null -and $r.Count -ge 0 }

Write-Summary -Results $results -Label "Get-SEPMHostGroupSummary Smoke Tests"
