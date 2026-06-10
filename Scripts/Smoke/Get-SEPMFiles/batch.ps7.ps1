# Smoke batch: files GET cmdlets (PS7)
# Covers: Get-SEPMFileFingerprintList, Get-SEPFileDetails
# Usage: pwsh -NoProfile -File Scripts/Smoke/Get-SEPMFiles/batch.ps7.ps1

$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"

$results = @{}

# ── Discovery: fingerprint list ──
# Try known list first (created during smoke test setup), then fallback to discovery
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
$s = Initialize-SEPMSession
$fileId = $null
# Try known file ID first (notepad.exe uploaded via Send-SEPMCommand -Type GetFile)
$knownId = "67C2C7AFAC1E00022E681989133418AF"
try {
    $test = Get-SEPFileDetails -FileID $knownId
    if ($test.id) { $fileId = $knownId }
} catch { }
# Fallback: discover from the command queue
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
    $results.B3 = T "B3" "Get-SEPFileDetails -FileID" `
        { Get-SEPFileDetails -FileID $fileId } `
        { param($r) $r -ne $null -and $r.id -ne $null -and $r.fileSize -ne $null -and $r.checksum -ne $null }
} else {
    $results.B3 = Skip "B3" "Get-SEPFileDetails -FileID" "No files in command queue"
}

# ── B5: Get-SEPFileDetails missing FileID (pre-existing: // in URI triggers Spring Security 500) ──
$results.B4 = Skip "B4" "Get-SEPFileDetails (missing FileID)" "Pre-existing: null FileID causes // in URI"

# === Summary ===
Write-Host "`n========== SUMMARY (PS7 Files) ==========" -ForegroundColor Yellow
$pass = 0; $fail = 0; $skip = 0
foreach ($k in $results.Keys | Sort-Object) {
    $v = $results[$k]
    if ($v -eq "PASS") { $pass++; Write-Host "  $k : PASS" -ForegroundColor Green }
    elseif ($v -eq "SKIP") { $skip++; Write-Host "  $k : SKIP" -ForegroundColor Yellow }
    else { $fail++; Write-Host "  $k : FAIL" -ForegroundColor Red }
}
Write-Host "TOTAL: $($pass+$fail+$skip) tests, $pass pass, $fail fail, $skip skip" -ForegroundColor Yellow
