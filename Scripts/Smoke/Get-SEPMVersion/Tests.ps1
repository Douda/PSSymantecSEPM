<#
.SYNOPSIS
    Shared smoke tests for Get-SEPMVersion.

.DESCRIPTION
    Dot-sourced by run.ps7.ps1 and run.ps51.ps1 after Common.ps1.
    Covers: returns version fields, API_VERSION string check, version string check.
#>

$results = @{}

$results.A1 = T "A1" "returns version fields" `
    { Get-SEPMVersion } `
    { param($r) $r -ne $null -and $r.API_SEQUENCE -ne $null -and $r.API_VERSION -ne $null -and $r.version -ne $null }

$results.A2 = T "A2" "API_VERSION is a non-empty string" `
    { Get-SEPMVersion } `
    { param($r) $r.API_VERSION -is [string] -and $r.API_VERSION.Length -gt 0 }

$results.A3 = T "A3" "version is a non-empty string" `
    { Get-SEPMVersion } `
    { param($r) $r.version -is [string] -and $r.version.Length -gt 0 }

Write-Summary -Results $results -Label "Get-SEPMVersion Smoke Tests"
