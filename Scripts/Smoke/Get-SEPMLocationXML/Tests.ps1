<#
.SYNOPSIS
    Shared smoke tests for Get-SEPMLocationXML.

.DESCRIPTION
    Dot-sourced by run.ps7.ps1 and run.ps51.ps1 after Common.ps1.
    Covers: retrieve location XML for a group/location.
#>

$results = @{}

$groupId = '1FB75121AC1E0002790C7332FFCDE857'
$locationId = '3BB37557AC1E00020BD263CF8AE23291'

# ── A1: Retrieve location XML for a group/location ──
$results.A1 = T "A1" "Get-SEPMLocationXML returns XML for group+location" `
    { Get-SEPMLocationXML -GroupID $groupId -LocationID $locationId } `
    { param($r)
        $r -ne $null
    }

Write-Summary -Results $results -Label "Get-SEPMLocationXML Smoke Tests"
