<#
.SYNOPSIS
    Shared smoke tests for Start-SEPMReplication.

.DESCRIPTION
    Dot-sourced by run.ps7.ps1 and run.ps51.ps1 after Common.ps1.
    Covers: replication with partner site name, no-parameter call.
#>

$results = @{}

# ── A1: Send with partner site name (null/error both acceptable) ──
$results.A1 = T "A1" "Send with partner" `
    {
        try {
            Start-SEPMReplication -partnerSiteName 'RemoteSiteTest' | Out-Null
            $true
        } catch {
            $msg = $_.Exception.Message
            $msg -match 'partner|site|replication|not found'
        }
    } `
    { param($r) $r -eq $true }

# ── A2: Call without parameters (null acceptable) ──
$results.A2 = T "A2" "No-param call" `
    { Start-SEPMReplication | Out-Null; $true } `
    { param($r) $r -eq $true }

# ── Summary ──
Write-Summary -Results $results -Label "Start-SEPMReplication Smoke Tests"
