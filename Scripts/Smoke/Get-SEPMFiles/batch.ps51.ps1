# Smoke batch: files GET cmdlets (PS 5.1)
# Covers: Get-SEPMFileFingerprintList, Get-SEPFileDetails
# Deploy: cp -r ./Output/PSSymantecSEPM /home/.../Windows/PSSymantecSEPM
# Run via WinRM: python3 Scripts/invoke-winrm.py 'C:\...\batch.ps51.ps1'

$ErrorActionPreference = "Continue"
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

$d = "$env:APPDATA\PSSymantecSEPM"
New-Item -ItemType Directory $d -Force | Out-Null
@{port=8446;ServerAddress="localhost"} | ConvertTo-Json | Set-Content "$d\config.json" -Force

Import-Module "$env:USERPROFILE\Desktop\Shared\PSSymantecSEPM\PSSymantecSEPM.psm1" -Force
$mod = Get-Module PSSymantecSEPM
& $mod { $script:SkipCert = $true }

function T {
    param($Id, $Label, [ScriptBlock]$Action, [ScriptBlock]$Assert)
    Write-Host "--- $Id : $Label ---" -ForegroundColor Cyan
    try {
        $result = & $Action
        if ($result -is [string] -and $result -like "Error:*") {
            Write-Host "  VERDICT: FAIL (API error: $result)" -ForegroundColor Red
            return "FAIL"
        }
        $ok = & $Assert $result
        if ($ok) { Write-Host "  VERDICT: PASS" -ForegroundColor Green; return "PASS" }
        else     { Write-Host "  VERDICT: FAIL" -ForegroundColor Red;   return "FAIL" }
    } catch {
        $errMsg = $_.Exception.Message
        Write-Host "  ERROR: $errMsg" -ForegroundColor Red
        return "FAIL"
    }
}

function Skip {
    param($Id, $Label, $Reason)
    Write-Host "--- $Id : $Label ---" -ForegroundColor Cyan
    Write-Host "  SKIP: $Reason" -ForegroundColor Yellow
    return "SKIP"
}

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

$results.B4 = Skip "B4" "Get-SEPFileDetails (missing FileID)" "Pre-existing: null FileID causes // in URI"

# === Summary ===
Write-Host "`n========== SUMMARY (PS5.1 Files) ==========" -ForegroundColor Yellow
$pass = 0; $fail = 0; $skip = 0
foreach ($k in $results.Keys | Sort-Object) {
    $v = $results[$k]
    if ($v -eq "PASS") { $pass++; Write-Host "  $k : PASS" -ForegroundColor Green }
    elseif ($v -eq "SKIP") { $skip++; Write-Host "  $k : SKIP" -ForegroundColor Yellow }
    else { $fail++; Write-Host "  $k : FAIL" -ForegroundColor Red }
}
Write-Host "TOTAL: $($pass+$fail+$skip) tests, $pass pass, $fail fail, $skip skip" -ForegroundColor Yellow