<#
.SYNOPSIS
    Shared smoke tests for Get-SEPMIpsPolicy.

.DESCRIPTION
    Dot-sourced by run.ps7.ps1 and run.ps51.ps1 after Common.ps1.
    Covers: retrieve IPS policy by name, retrieve via -PolicyList.
#>

$results = @{}

# ── A1: Retrieve IPS policy by name ──
$results.A1 = T "A1" "Get-SEPMIpsPolicy by name returns IPS policy" `
    { Get-SEPMIpsPolicy -PolicyName "Intrusion Prevention policy" } `
    { param($r)
        $r -ne $null -and
        $r.name -eq 'Intrusion Prevention policy' -and
        $null -ne $r.enabled
    }

# ── A2: Retrieve IPS policy via -PolicyList (skips redundant summary fetch) ──
$results.A2 = T "A2" "Get-SEPMIpsPolicy with -PolicyList returns IPS policy" `
    { $summaries = Get-SEPMPoliciesSummary -PolicyType ips; Get-SEPMIpsPolicy -PolicyName "Intrusion Prevention policy" -PolicyList $summaries } `
    { param($r)
        $r -ne $null -and
        $r.name -eq 'Intrusion Prevention policy' -and
        $null -ne $r.enabled
    }

Write-Summary -Results $results -Label "Get-SEPMIpsPolicy Smoke Tests"
