# Smoke batch: Get-SEPMVersion (PS 5.1)
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

$SmokeCredPassword = ConvertTo-SecureString -String 'MyComplexPassword1!' -AsPlainText -Force
$SmokeCredential   = New-Object System.Management.Automation.PSCredential -ArgumentList 'admin', $SmokeCredPassword
Set-SEPMAuthentication -Credential $SmokeCredential -ErrorAction SilentlyContinue

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

$results.A1 = T "A1" "Get-SEPMVersion" `
    { Get-SEPMVersion } `
    { param($r) $r -ne $null -and $r.API_SEQUENCE -ne $null -and $r.API_VERSION -ne $null -and $r.version -ne $null }

# === Summary ===
Write-Host "`n========== SUMMARY (PS5.1 Get-SEPMVersion) ==========" -ForegroundColor Yellow
$pass = 0; $fail = 0
foreach ($k in $results.Keys | Sort-Object) {
    $v = $results[$k]
    if ($v -eq "PASS") { $pass++; Write-Host "  $k : PASS" -ForegroundColor Green }
    else { $fail++; Write-Host "  $k : FAIL" -ForegroundColor Red }
}
Write-Host "TOTAL: $($pass+$fail) tests, $pass pass, $fail fail" -ForegroundColor Yellow
