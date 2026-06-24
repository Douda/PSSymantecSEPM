<#
.SYNOPSIS
    Smoke tests for Get-SEPMLocation and Get-SEPMLocationXML cmdlets.

.DESCRIPTION
    Shared test logic dot-sourced by run.ps7.ps1 / run.ps51.ps1 after
    Common.ps1 and Bootstrap.ps1 have been loaded.
#>

$results = @{}

# ── Discovery ──
$allGroups = Get-SEPMGroups
if (-not $allGroups -or $allGroups.Count -eq 0) {
    Write-Error "No groups found — cannot test locations"
    exit 1
}
$groupId = $allGroups[0].id
Write-Host "Group: $($allGroups[0].name) ($groupId)" -ForegroundColor Gray

# ── C1: Get-SEPMLocation -GroupID ──
$results.C1 = T "C1" "Get-SEPMLocation -GroupID" `
    { Get-SEPMLocation -GroupID $groupId } `
    { param($r) $r -ne $null -and $r.Count -gt 0 -and $r[0].locationName -ne $null }

# ── C2: Pipeline ──
$results.C2 = T "C2" "Get-SEPMGroups | Get-SEPMLocation" `
    { $allGroups | Select-Object -First 1 | Get-SEPMLocation } `
    { param($r) $r -ne $null -and $r.Count -gt 0 }

# ── Discover location for XML ──
$allLocs = Get-SEPMLocation -GroupID $groupId
if ($allLocs -and $allLocs.Count -gt 0) {
    $locId = $allLocs[0].locationId
    Write-Host "Location: $($allLocs[0].locationName) ($locId)" -ForegroundColor Gray

    $results.C3 = T "C3" "Get-SEPMLocationXML" `
        { Get-SEPMLocationXML -GroupID $groupId -LocationID $locId } `
        { param($r) $r -ne $null }
} else {
    Write-Error "No locations found in group"
}

# ── C4: Get-SEPMLocation with -GroupList ──
$results.C4 = T "C4" "Get-SEPMLocation -GroupID -GroupList" `
    { Get-SEPMLocation -GroupID $groupId -GroupList $allGroups } `
    { param($r) $r -ne $null -and $r.Count -gt 0 -and $r[0].groupName -ne $null -and $r[0].locationName -ne $null }

# ── C5: -GroupList skips Get-SEPMGroups (verify output matches) ──
$results.C5 = T "C5" "Get-SEPMLocation with -GroupList matches standard call" `
    {
        $standard  = Get-SEPMLocation -GroupID $groupId
        $fromList  = Get-SEPMLocation -GroupID $groupId -GroupList $allGroups
        return @{ standard = $standard; fromList = $fromList }
    } `
    { param($r) $r.standard.Count -eq $r.fromList.Count -and $r.standard[0].locationName -eq $r.fromList[0].locationName }

# ── Summary ──
Write-Summary -Results $results -Label "Get-SEPMLocations"
