$ErrorActionPreference = "Continue"
$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"

Write-Host "=== Smoke: Send-SEPMCommandGetFile (PS7) ==="

$results = @{}

function TE {
    param($Id, $Label, [ScriptBlock]$Action)
    Write-Host "--- $Id : $Label ---" -ForegroundColor Cyan
    try {
        $result = & $Action
        if ($null -eq $result) {
            Write-Host "  VERDICT: FAIL (null response)" -ForegroundColor Red
            return "FAIL"
        }
        Write-Host "  VERDICT: PASS (API reached)" -ForegroundColor Green
        return "PASS"
    } catch {
        Write-Host "  VERDICT: FAIL (exception: $($_.Exception.Message))" -ForegroundColor Red
        return "FAIL"
    }
}

$results.C1 = TE -Id "C1" -Label "GetFile SHA256 with non-existent computer reaches API" `
    -Action { Send-SEPMCommandGetFile -ComputerName 'NonExistentComputer12345' -SHA256 'ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890' -FilePath 'C:\Temp\malware.exe' -Source 'BOTH' }

$results.C2 = TE -Id "C2" -Label "GetFile MD5 with non-existent computer reaches API" `
    -Action { Send-SEPMCommandGetFile -ComputerName 'NonExistentComputer12345' -MD5 'ABCDEF1234567890ABCDEF1234567890' -FilePath 'C:\Temp\test.dll' }

$results.C3 = TE -Id "C3" -Label "GetFile SHA1 with non-existent computer reaches API" `
    -Action { Send-SEPMCommandGetFile -ComputerName 'NonExistentComputer12345' -SHA1 'ABCDEF1234567890ABCDEF1234567890ABCDEF12' -FilePath 'C:\Temp\binary.sys' -Source 'FILESYSTEM ' }

$results.C4 = TE -Id "C4" -Label "GetFile via pipeline reaches API" `
    -Action { 'NonExistentComputer12345' | Send-SEPMCommandGetFile -SHA256 'ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890' -FilePath 'C:\Temp\malware.exe' }

$pass = ($results.Values | Where-Object { $_ -eq 'PASS' }).Count
$fail = ($results.Values | Where-Object { $_ -eq 'FAIL' }).Count
Write-Host "`n=== Results: $pass PASS, $fail FAIL ===" -ForegroundColor $(if ($fail -gt 0) { 'Red' } else { 'Green' })

if ($fail -gt 0) {
    Write-Error "Smoke tests failed: $fail failure(s)"
    exit 1
}
