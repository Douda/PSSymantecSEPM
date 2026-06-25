<#
.SYNOPSIS
    Shared smoke tests for simple GET cmdlets batch 2.

.DESCRIPTION
    Dot-sourced by run.ps7.ps1 and run.ps51.ps1 after Common.ps1.
    Covers: Get-SEPMAdmins, Get-SEPMDomain, Get-SEPMClientStatus,
            Get-SEPMClientVersion, Get-SEPMClientDefVersions,
            Get-SEPMReplicationStatus, Get-SEPMThreatStats.
#>

$results = @{}

# ── A1: Get-SEPMAdmins ──
$results.A1 = T "A1" "Get-SEPMAdmins" `
    { Get-SEPMAdmins } `
    { param($r) $r -is [array] -and $r.Count -gt 0 -and $r[0].loginName -ne $null }

# ── B1: Get-SEPMDomain ──
$results.B1 = T "B1" "Get-SEPMDomain" `
    { Get-SEPMDomain } `
    { param($r) $r -ne $null -and $r.id -ne $null -and $r.name -ne $null }

# ── C1: Get-SEPMClientStatus ──
$results.C1 = T "C1" "Get-SEPMClientStatus" `
    { Get-SEPMClientStatus } `
    { param($r) $r -is [array] -and $r.Count -gt 0 -and $r[0].status -ne $null -and $r[0].clientsCount -ne $null }

# ── D1: Get-SEPMClientVersion ──
$results.D1 = T "D1" "Get-SEPMClientVersion" `
    { Get-SEPMClientVersion } `
    { param($r) $r -is [array] -and $r.Count -gt 0 -and $r[0].version -ne $null -and $r[0].clientsCount -ne $null }

# ── E1: Get-SEPMClientDefVersions ──
$results.E1 = T "E1" "Get-SEPMClientDefVersions" `
    { Get-SEPMClientDefVersions } `
    { param($r) $r -is [array] -and $r.Count -gt 0 -and $r[0].version -ne $null -and $r[0].clientsCount -ne $null }

# ── F1: Get-SEPMReplicationStatus ──
$results.F1 = T "F1" "Get-SEPMReplicationStatus" `
    { Get-SEPMReplicationStatus } `
    { param($r) $r.Count -gt 0 -and $r[0].siteName -ne $null -and $r[0].id -ne $null }

# ── G1: Get-SEPMThreatStats ──
$results.G1 = T "G1" "Get-SEPMThreatStats" `
    { Get-SEPMThreatStats } `
    { param($r) $r -ne $null -and $r.lastUpdated -ne $null -and $r.infectedClients -ne $null }

Write-Summary -Results $results -Label "Simple GETs Batch 2"
