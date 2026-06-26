<#
.SYNOPSIS
    Shared smoke tests for Get-SEPMPoliciesSummary.

.DESCRIPTION
    Dot-sourced by run.ps7.ps1 and run.ps51.ps1 after Common.ps1.
    Covers: retrieve all policies summary, filter by type, and -GroupList skip-param.
#>

$results = @{}

# ── A1: Retrieve all policies summary ──
$results.A1 = T "A1" "Get-SEPMPoliciesSummary returns all policies" `
    { Get-SEPMPoliciesSummary } `
    { param($r)
        $r -ne $null -and
        $r.Count -gt 0 -and
        $null -ne $r[0].name -and
        $null -ne $r[0].id -and
        $null -ne $r[0].policytype
    }

# ── A2: Filter by policy type ──
$results.A2 = T "A2" "Get-SEPMPoliciesSummary -PolicyType fw returns firewall policies" `
    { Get-SEPMPoliciesSummary -PolicyType fw } `
    { param($r)
        $r -ne $null -and
        $r.Count -gt 0 -and
        $r[0].name -ne $null -and
        $r[0].policytype -eq 'fw'
    }

# ── A3: Get all policies summary with -GroupList skip-param ──
$allGroups = Get-SEPMGroups
$results.A3 = T "A3" "Get-SEPMPoliciesSummary -GroupList skips internal group fetch" `
    { Get-SEPMPoliciesSummary -GroupList $allGroups } `
    { param($r)
        $r -ne $null -and
        $r.Count -gt 0 -and
        $null -ne $r[0].name -and
        $null -ne $r[0].id -and
        $null -ne $r[0].policytype
    }

# ── A4: -GroupList output matches standard call ──
$results.A4 = T "A4" "Get-SEPMPoliciesSummary with -GroupList matches standard output" `
    {
        $standard = Get-SEPMPoliciesSummary
        $fromList = Get-SEPMPoliciesSummary -GroupList $allGroups
        return @{ standard = $standard; fromList = $fromList }
    } `
    { param($r)
        $r.standard.Count -eq $r.fromList.Count -and
        $r.standard[0].name -eq $r.fromList[0].name -and
        $r.standard[0].policytype -eq $r.fromList[0].policytype -and
        $r.standard[0].enabled -eq $r.fromList[0].enabled
    }

Write-Summary -Results $results -Label "Get-SEPMPoliciesSummary Smoke Tests"
