# Smoke batch: infrastructure GET cmdlets (PS 5.1)
# Deploy: cp -r ./Output/PSSymantecSEPM /home/.../Windows/PSSymantecSEPM
# Run via WinRM: python3 Scripts/invoke-winrm.py 'C:\...\batch.ps51.ps1'
# Usage: pwsh -NoProfile -File Scripts/Smoke/Get-SEPMInfrastructure/batch.ps51.ps1

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

$results = @{}

$results.A1 = T "A1" "Get-SEPGUPList" `
    { Get-SEPGUPList } `
    { param($r) ($null -eq $r) -or ($r -is [array] -or $r -is [hashtable]) }

$results.A2 = T "A2" "Get-SEPMLicense" `
    { Get-SEPMLicense } `
    { param($r) $r -ne $null -and ($r -is [PSCustomObject] -or $r -is [hashtable]) }

$results.A3 = T "A3" "Get-SEPMLicense -Summary" `
    { Get-SEPMLicense -Summary } `
    { param($r) $r -ne $null -and ($r -is [hashtable]) }

$results.A4 = T "A4" "Get-SEPMDatabaseInfo" `
    { Get-SEPMDatabaseInfo } `
    { param($r) $r -ne $null -and ($r -is [hashtable]) -and $r.database -ne $null -and $r.name -ne $null }

$results.A5 = T "A5" "Get-SEPMLatestDefinition" `
    { Get-SEPMLatestDefinition } `
    { param($r) $r -ne $null -and ($r -is [hashtable]) -and $r.contentName -ne $null }

# === Summary ===
Write-Host "`n========== SUMMARY (PS5.1 Infrastructure) ==========" -ForegroundColor Yellow
$pass = 0; $fail = 0
foreach ($k in $results.Keys | Sort-Object) {
    $v = $results[$k]
    if ($v -eq "PASS") { $pass++; Write-Host "  $k : PASS" -ForegroundColor Green }
    else { $fail++; Write-Host "  $k : FAIL" -ForegroundColor Red }
}
Write-Host "TOTAL: $($pass+$fail) tests, $pass pass, $fail fail" -ForegroundColor Yellow