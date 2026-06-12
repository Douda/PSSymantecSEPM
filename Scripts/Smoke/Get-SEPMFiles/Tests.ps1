<#
.SYNOPSIS
    Shared smoke tests for Get-SEPMFileFingerprintList and Get-SEPFileDetails.

.DESCRIPTION
    Dot-sourced by run.ps7.ps1 and run.ps51.ps1 after Common.ps1.
    Covers: Get-SEPMFileFingerprintList by ID and name, Get-SEPFileDetails by ID.
    Includes pre-test discovery of fingerprint lists and file IDs from the command queue.
#>

$results = @{}

# ── Discovery: fingerprint list ──
$FP_ID   = "2AF80AC20C804119826BE077ECE49C1C"
$FP_NAME = $null
try {
    $test = Get-SEPMFileFingerprintList -FingerprintListID $FP_ID
    if ($test.name) { $FP_NAME = $test.name }
} catch { }
if (-not $FP_NAME) {
    $fpl = Get-SEPMFileFingerprintList
    if ($fpl -and $fpl.Count -gt 0) {
        $FP_ID   = $fpl[0].id
        $FP_NAME = $fpl[0].name
    }
}

if ($FP_NAME) {
    Write-Host "Discovered fingerprint list: $FP_NAME ($FP_ID)" -ForegroundColor Gray

    $results.B1 = T "B1" "Get-SEPMFileFingerprintList -FingerprintListID" `
        { Get-SEPMFileFingerprintList -FingerprintListID $FP_ID } `
        { param($r) $r -ne $null -and $r.name -ne $null -and $r.hashType -ne $null }

    $results.B2 = T "B2" "Get-SEPMFileFingerprintList -FingerprintListName" `
        { Get-SEPMFileFingerprintList -FingerprintListName $FP_NAME } `
        { param($r) ($r -ne $null) -and ($r.name -eq $FP_NAME -or ($r -is [array] -and $r[0].name -eq $FP_NAME) -or ($r -is [hashtable] -and $r.name -eq $FP_NAME)) }
} else {
    $results.B1 = Skip "B1" "Get-SEPMFileFingerprintList -FingerprintListID" "No fingerprint lists"
    $results.B2 = Skip "B2" "Get-SEPMFileFingerprintList -FingerprintListName" "No fingerprint lists"
}

# ── Discovery: file in command queue ──
$fileId = $null
# Try known file ID first (notepad.exe uploaded via Send-SEPMCommand -Type GetFile)
$knownId = "67C2C7AFAC1E00022E681989133418AF"
try {
    $test = Get-SEPFileDetails -FileID $knownId
    if ($test.id) { $fileId = $knownId }
} catch { }

if ($fileId) {
    Write-Host "Discovered file ID: $fileId" -ForegroundColor Gray
    $results.B3 = T "B3" "Get-SEPFileDetails -FileID" `
        { Get-SEPFileDetails -FileID $fileId } `
        { param($r) $r -ne $null -and $r.id -ne $null -and $r.fileSize -ne $null -and $r.checksum -ne $null }
} else {
    $results.B3 = Skip "B3" "Get-SEPFileDetails -FileID" "No files in command queue"
}

# ── B4: Get-SEPFileDetails missing FileID (pre-existing: // in URI triggers Spring Security 500) ──
$results.B4 = Skip "B4" "Get-SEPFileDetails (missing FileID)" "Pre-existing: null FileID causes // in URI"

# ── Summary ──
Write-Summary -Results $results -Label "Get-SEPMFiles Smoke Tests"
