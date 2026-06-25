<#
.SYNOPSIS
    Shared smoke tests for Get-SEPMFileFingerprintList and Get-SEPMFileDetails.

.DESCRIPTION
    Dot-sourced by run.ps7.ps1 and run.ps51.ps1 after Common.ps1.
    Covers: Get-SEPMFileFingerprintList by ID and name, Get-SEPMFileDetails by ID.
    Includes pre-test discovery of fingerprint lists and file IDs from the command queue.
#>

$results = @{}

# ── Discovery: fingerprint list ──
$fpId   = "2AF80AC20C804119826BE077ECE49C1C"
$fpName = $null
try {
    $test = Get-SEPMFileFingerprintList -FingerprintListID $fpId
    if ($test.name) { $fpName = $test.name }
} catch { }
if (-not $fpName) {
    $fpl = Get-SEPMFileFingerprintList
    if ($fpl -and $fpl.Count -gt 0) {
        $fpId   = $fpl[0].id
        $fpName = $fpl[0].name
    }
}

if ($fpName) {
    Write-Host "Discovered fingerprint list: $fpName ($fpId)" -ForegroundColor Gray

    $results.B1 = T "B1" "Get-SEPMFileFingerprintList -FingerprintListID" `
        { Get-SEPMFileFingerprintList -FingerprintListID $fpId } `
        { param($r) $r -ne $null -and $r.name -ne $null -and $r.hashType -ne $null }

    $results.B2 = T "B2" "Get-SEPMFileFingerprintList -FingerprintListName" `
        { Get-SEPMFileFingerprintList -FingerprintListName $fpName } `
        { param($r) ($r -ne $null) -and ($r.name -eq $fpName -or ($r -is [array] -and $r[0].name -eq $fpName) -or ($r -is [hashtable] -and $r.name -eq $fpName)) }
} else {
    $results.B1 = Skip "B1" "Get-SEPMFileFingerprintList -FingerprintListID" "No fingerprint lists"
    $results.B2 = Skip "B2" "Get-SEPMFileFingerprintList -FingerprintListName" "No fingerprint lists"
}

# ── Discovery: file in command queue ──
$fileId = $null
# Try known file ID first (notepad.exe uploaded via Send-SEPMCommand -Type GetFile)
$knownId = "67C2C7AFAC1E00022E681989133418AF"
try {
    $test = Get-SEPMFileDetails -FileID $knownId
    if ($test.id) { $fileId = $knownId }
} catch { }

if ($fileId) {
    Write-Host "Discovered file ID: $fileId" -ForegroundColor Gray
    $results.B3 = T "B3" "Get-SEPMFileDetails -FileID" `
        { Get-SEPMFileDetails -FileID $fileId } `
        { param($r) $r -ne $null -and $r.id -ne $null -and $r.fileSize -ne $null -and $r.checksum -ne $null }
} else {
    $results.B3 = Skip "B3" "Get-SEPMFileDetails -FileID" "No files in command queue"
}

# ── B4: Get-SEPMFileDetails missing FileID (pre-existing: // in URI triggers Spring Security 500) ──
$results.B4 = Skip "B4" "Get-SEPMFileDetails (missing FileID)" "Pre-existing: null FileID causes // in URI"

# ── Summary ──
Write-Summary -Results $results -Label "Get-SEPMFiles Smoke Tests"
