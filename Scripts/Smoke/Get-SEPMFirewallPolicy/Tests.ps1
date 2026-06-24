<#
.SYNOPSIS
    Shared smoke tests for Get-SEPMFirewallPolicy.

.DESCRIPTION
    Dot-sourced by run.ps7.ps1 and run.ps51.ps1 after Common.ps1.
    Covers: -All returns all FW policies, type check, field population.
#>

$results = @{}

# ── A1: -All returns all FW policies ──
$results.A1 = T "A1" "Get-SEPMFirewallPolicy -All returns all FW policies" `
    { Get-SEPMFirewallPolicy -All } `
    { param($r)
        $r -ne $null -and
        $r.Count -gt 0 -and
        $r[0].PSObject.TypeNames[0] -eq 'SEPM.FirewallPolicy' -and
        -not [string]::IsNullOrEmpty($r[0].name) -and
        $null -ne $r[0].enabled
    }

# ── A2: Verify all policies share correct type ──
$results.A2 = T "A2" "All returned policies have PSTypeName SEPM.FirewallPolicy" `
    { Get-SEPMFirewallPolicy -All } `
    { param($r)
        ($r | ForEach-Object { $_.PSObject.TypeNames[0] } | Select-Object -Unique).Count -eq 1 -and
        $r[0].PSObject.TypeNames[0] -eq 'SEPM.FirewallPolicy'
    }

# ── A3: Verify policy fields are populated ──
$results.A3 = T "A3" "All policies have non-empty name, id, enabled" `
    { Get-SEPMFirewallPolicy -All } `
    { param($r)
        $ok = $true
        foreach ($p in $r) {
            if ([string]::IsNullOrEmpty($p.name)) { $ok = $false; break }
            if ($null -eq $p.enabled) { $ok = $false; break }
        }
        $ok
    }

# ── B1: -All -PolicyList returns same results as -All alone ──
$results.B1 = T "B1" "Get-SEPMFirewallPolicy -All -PolicyList from summaries returns all FW policies" `
    { 
        $summaries = Get-SEPMPoliciesSummary -PolicyType fw
        if ($null -eq $summaries -or $summaries.Count -eq 0) { throw 'No FW policy summaries found' }
        Get-SEPMFirewallPolicy -All -PolicyList $summaries
    } `
    { param($r)
        $r -ne $null -and
        $r.Count -gt 0 -and
        $r[0].PSObject.TypeNames[0] -eq 'SEPM.FirewallPolicy' -and
        -not [string]::IsNullOrEmpty($r[0].name)
    }

Write-Summary -Results $results -Label "Get-SEPMFirewallPolicy Smoke Tests"
