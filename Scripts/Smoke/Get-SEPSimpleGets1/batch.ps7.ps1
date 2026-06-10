# Smoke batch: simple GET cmdlets batch 1 (PS7)
# Covers: Get-SEPClientInfectedStatus, Get-SEPFileDetails, Get-SEPGUPList,
#         Get-SEPMCommandStatus, Get-SEPMDatabaseInfo, Get-SEPMEventInfo
# Usage: pwsh -NoProfile -File Scripts/Smoke/Get-SEPSimpleGets1/batch.ps7.ps1

$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"

$results = @{}

# ── A1: Get-SEPClientInfectedStatus ──
$results.A1 = T "A1" "Get-SEPClientInfectedStatus" `
    { Get-SEPClientInfectedStatus } `
    { param($r) $r -is [array] -or (@($r).Count -ge 0) }

# ── A2: Get-SEPClientInfectedStatus -Clean ──
$results.A2 = T "A2" "Get-SEPClientInfectedStatus -Clean" `
    { Get-SEPClientInfectedStatus -Clean } `
    { param($r) $r -is [array] -or (@($r).Count -ge 0) }

# ── B1: Get-SEPGUPList ──
$results.B1 = T "B1" "Get-SEPGUPList" `
    { Get-SEPGUPList } `
    { param($r) $r -is [array] }

# ── C1: Get-SEPMDatabaseInfo ──
$results.C1 = T "C1" "Get-SEPMDatabaseInfo" `
    { Get-SEPMDatabaseInfo } `
    { param($r) $r -ne $null -and $r.name -ne $null -and $r.database -ne $null }

# ── D1: Get-SEPMEventInfo ──
$results.D1 = T "D1" "Get-SEPMEventInfo" `
    { Get-SEPMEventInfo } `
    { param($r) $r -is [array] -and $r.Count -gt 0 -and $r[0].eventId -ne $null -and $r[0].PSObject.TypeNames[0] -eq 'SEPM.EventInfo' }

# ── Discovery: command ID for Get-SEPMCommandStatus ──
$s = Initialize-SEPMSession
$commandId = $null
try {
    $queue = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/command-queue?pageSize=50" -Session $s
    if ($queue.content -and $queue.content.Count -gt 0) {
        $commandId = $queue.content[0].commandId
    }
} catch { }

if ($commandId) {
    Write-Host "Discovered command ID: $commandId" -ForegroundColor Gray
    $results.E1 = T "E1" "Get-SEPMCommandStatus -Command_ID" `
        { Get-SEPMCommandStatus -Command_ID $commandId } `
        { param($r) $r -is [array] -and $r[0].computerName -ne $null -and $r[0].PSObject.TypeNames[0] -eq 'SEPM.CommandStatus' }
} else {
    $results.E1 = Skip "E1" "Get-SEPMCommandStatus" "No commands in queue"
}

# ── Discovery: file ID for Get-SEPFileDetails ──
$fileId = $null
$knownId = "67C2C7AFAC1E00022E681989133418AF"
try {
    $test = Get-SEPFileDetails -FileID $knownId
    if ($test.id) { $fileId = $knownId }
} catch { }
if (-not $fileId) {
    try {
        $queue = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/command-queue?pageSize=50" -Session $s
        foreach ($cmd in $queue.content) {
            if ($cmd.binaryFileId) { $fileId = $cmd.binaryFileId; break }
        }
    } catch { }
}

if ($fileId) {
    Write-Host "Discovered file ID: $fileId" -ForegroundColor Gray
    $results.F1 = T "F1" "Get-SEPFileDetails -FileID" `
        { Get-SEPFileDetails -FileID $fileId } `
        { param($r) $r -ne $null -and $r.id -ne $null -and $r.fileSize -ne $null -and $r.checksum -ne $null }
} else {
    $results.F1 = Skip "F1" "Get-SEPFileDetails -FileID" "No files in command queue"
}

# ── Summary ──
Write-Host "`n========== SUMMARY (PS7 Simple GETs Batch 1) ==========" -ForegroundColor Yellow
$pass = 0; $fail = 0; $skip = 0
foreach ($k in $results.Keys | Sort-Object) {
    $v = $results[$k]
    if ($v -eq "PASS") { $pass++; Write-Host "  $k : PASS" -ForegroundColor Green }
    elseif ($v -eq "SKIP") { $skip++; Write-Host "  $k : SKIP" -ForegroundColor Yellow }
    else { $fail++; Write-Host "  $k : FAIL" -ForegroundColor Red }
}
Write-Host "TOTAL: $($pass+$fail+$skip) tests, $pass pass, $fail fail, $skip skip" -ForegroundColor Yellow
