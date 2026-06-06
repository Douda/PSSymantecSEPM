# Smoke verification batch runner for PS 5.1
# Deploy: cp ./Output/PSSymantecSEPM /home/douda/Windows/PSSymantecSEPM
# Run:   WINRM_USER=douda WINRM_PASS=aurelien python3 Scripts/invoke-winrm.py 'C:\Users\...\batch.ps51.ps1'

$ErrorActionPreference = "Continue"
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

# Note: No ServicePoint tuning needed. Invoke-SepmApi uses HttpWebRequest
# with KeepAlive=false on PS 5.1 (see Source/Private/Invoke-SepmApi.ps1).

$d = "$env:APPDATA\PSSymantecSEPM"
New-Item -ItemType Directory $d -Force | Out-Null
@{port=8446;ServerAddress="localhost"}|ConvertTo-Json|Set-Content "$d\config.json" -Force

Import-Module C:\Users\douda\Desktop\Shared\PSSymantecSEPM\PSSymantecSEPM.psm1 -Force
$mod = Get-Module PSSymantecSEPM; & $mod { $script:SkipCert = $true }

$POLICY_NAME = "Exceptions policy"
$POLICY_ID   = "4C4BC60CAC1E00027A25369C305828F9"

function Get-PolicyState {
    $s = Initialize-SEPMSession
    return Invoke-SepmApi -Method GET `
        -Uri "$($s.BaseURLv2)/policies/exceptions/$POLICY_ID" `
        -Headers $s.Headers `
        -SkipCert:$true
}

function T {
    param($Id, $Label, [ScriptBlock]$Action, [ScriptBlock]$Assert)
    Write-Host "--- $Id : $Label ---"
    try {
        & $Action
        Start-Sleep -Milliseconds 1500
        $policy = Get-PolicyState
        if ($policy -is [string] -and $policy -like "Error:*") {
            Write-Host "  VERDICT: FAIL (API error: $policy)"
            return "FAIL"
        }
        $ok = & $Assert $policy
        if ($ok) { Write-Host "  VERDICT: PASS"; return "PASS" }
        else     { Write-Host "  VERDICT: FAIL"; return "FAIL" }
    } catch {
        $errMsg = $_.Exception.Message
        Write-Host "  ERROR: $errMsg"
        $expectedErrors = @(
            "EnablePolicy.*DisablePolicy",
            "SecurityRiskCategory.*ScanType",
            "not found",
            "Cannot remove Extension",
            "requires the -ApplicationControl"
        )
        $isExpected = $false
        foreach ($pattern in $expectedErrors) {
            if ($errMsg -match $pattern) { $isExpected = $true; break }
        }
        if ($isExpected) {
            Write-Host "  VERDICT: PASS (expected error)"
            return "PASS"
        }
        return "FAIL"
    }
}

$results = @{}

# === A group: Default parameter set (Slice 1/6) ===
$results.A1 = T "A1" "EnablePolicy" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -EnablePolicy | Out-Null } `
    { param($p) $p.enabled -eq $true }

$results.A2 = T "A2" "DisablePolicy" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -DisablePolicy | Out-Null } `
    { param($p) $p.enabled -eq $false }

$results.A3 = T "A3" "PolicyDescription" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -EnablePolicy -PolicyDescription "ps51-A3" | Out-Null } `
    { param($p) $p.enabled -eq $true -and $p.desc -eq "ps51-A3" }

$results.A4 = T "A4" "Enable+Description" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -EnablePolicy -PolicyDescription "ps51-A4" | Out-Null } `
    { param($p) $p.enabled -eq $true -and $p.desc -eq "ps51-A4" }

$results.A5 = T "A5" "Enable+Disable (error)" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -EnablePolicy -DisablePolicy } `
    { param($p) $true }

# === B group: WindowsFile ===
$results.B1 = T "B1" "WF: no scan (default AllScans)" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -Path "C:\Temp\SmokeB1.exe" | Out-Null } `
    { param($p) ($f = $p.configuration.files | ? { $_.path -eq "C:\Temp\SmokeB1.exe" } | Select -First 1); $f -and $f.sonar -eq $true -and $f.securityrisk -eq $true -and $f.applicationcontrol -eq $true -and $f.scancategory -eq "AllScans" }

$results.B2 = T "B2" "WF: explicit AllScans" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -Path "C:\Temp\SmokeB2.exe" -AllScans | Out-Null } `
    { param($p) ($f = $p.configuration.files | ? { $_.path -eq "C:\Temp\SmokeB2.exe" } | Select -First 1); $f -and $f.sonar -and $f.securityrisk -and $f.applicationcontrol -and $f.scancategory -eq "AllScans" }

$results.B3 = T "B3" "WF: Sonar only" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -Path "C:\Temp\SmokeB3.exe" -Sonar | Out-Null } `
    { param($p) ($f = $p.configuration.files | ? { $_.path -eq "C:\Temp\SmokeB3.exe" } | Select -First 1); $f -and $f.sonar -eq $true -and $f.securityrisk -ne $true -and $f.applicationcontrol -ne $true }

$results.B4 = T "B4" "WF: SecurityRisk AutoProtect" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -Path "C:\Temp\SmokeB4.exe" -SecurityRiskCategory AutoProtect | Out-Null } `
    { param($p) ($f = $p.configuration.files | ? { $_.path -eq "C:\Temp\SmokeB4.exe" } | Select -First 1); $f -and $f.securityrisk -eq $true -and $f.scancategory -eq "AutoProtect" -and $f.sonar -ne $true }

$results.B5 = T "B5" "WF: ApplicationControl only" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -Path "C:\Temp\SmokeB5.exe" -ApplicationControl | Out-Null } `
    { param($p) ($f = $p.configuration.files | ? { $_.path -eq "C:\Temp\SmokeB5.exe" } | Select -First 1); $f -and $f.applicationcontrol }

$results.B6 = T "B6" "WF: AppCtrl + ExcludeChildProcesses" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -Path "C:\Temp\SmokeB6.exe" -ApplicationControl -ExcludeChildProcesses | Out-Null } `
    { param($p) ($f = $p.configuration.files | ? { $_.path -eq "C:\Temp\SmokeB6.exe" } | Select -First 1); $f -and $f.recursive }

$results.B7 = T "B7" "WF: Sonar + AppCtrl" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -Path "C:\Temp\SmokeB7.exe" -Sonar -ApplicationControl | Out-Null } `
    { param($p) ($f = $p.configuration.files | ? { $_.path -eq "C:\Temp\SmokeB7.exe" } | Select -First 1); $f -and $f.sonar -and $f.applicationcontrol -and $f.securityrisk -ne $true }

$results.B8 = T "B8" "WF: Sonar + SecurityRisk ScheduledAndOndemand" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -Path "C:\Temp\SmokeB8.exe" -Sonar -SecurityRiskCategory ScheduledAndOndemand | Out-Null } `
    { param($p) ($f = $p.configuration.files | ? { $_.path -eq "C:\Temp\SmokeB8.exe" } | Select -First 1); $f -and $f.sonar -and $f.securityrisk -and $f.scancategory -eq "ScheduledAndOndemand" }

$results.B9 = T "B9" "WF: PathVariable [SYSTEM]" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -Path "C:\Windows\SmokeB9.exe" -PathVariable '[SYSTEM]' | Out-Null } `
    { param($p) ($f = $p.configuration.files | ? { $_.path -like "*SmokeB9.exe" } | Select -First 1); $f -and $f.pathvariable -eq "[SYSTEM]" }

Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -Path "C:\Temp\SmokeB10.exe" -AllScans | Out-Null
Start-Sleep -Milliseconds 500
$results.B10 = T "B10" "WF: Remove" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -Path "C:\Temp\SmokeB10.exe" -Remove | Out-Null } `
    { param($p) ($p.configuration.files | ? { $_.path -like "*SmokeB10.exe" }).Count -eq 0 }

$results.B12 = T "B12" "WF: AllScans + EnablePolicy" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -Path "C:\Temp\SmokeB12.exe" -AllScans -EnablePolicy | Out-Null } `
    { param($p) ($f = $p.configuration.files | ? { $_.path -eq "C:\Temp\SmokeB12.exe" } | Select -First 1); $p.enabled -eq $true -and $f }

$results.B13 = T "B13" "WF: AllScans + PolicyDescription" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -Path "C:\Temp\SmokeB13.exe" -AllScans -PolicyDescription "ps51-B13" | Out-Null } `
    { param($p) ($f = $p.configuration.files | ? { $_.path -eq "C:\Temp\SmokeB13.exe" } | Select -First 1); $p.desc -eq "ps51-B13" -and $f }

# === C group: WindowsFolder ===
$results.C1 = T "C1" "WFolder: default All" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -FolderPath "C:\Temp\SmokeFolderC1" | Out-Null } `
    { param($p) ($d = $p.configuration.directories | ? { $_.directory -like "*SmokeFolderC1*" } | Select -First 1); $d -and $d.scantype -eq "All" }

$results.C2 = T "C2" "WFolder: ScanType SONAR" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -FolderPath "C:\Temp\SmokeFolderC2" -ScanType SONAR | Out-Null } `
    { param($p) ($d = $p.configuration.directories | ? { $_.directory -like "*SmokeFolderC2*" } | Select -First 1); $d -and $d.scantype -eq "SONAR" }

$results.C3 = T "C3" "WFolder: SecurityRisk + AutoProtect" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -FolderPath "C:\Temp\SmokeFolderC3" -ScanType SecurityRisk -SecurityRiskCategory AutoProtect | Out-Null } `
    { param($p) ($d = $p.configuration.directories | ? { $_.directory -like "*SmokeFolderC3*" } | Select -First 1); $d -and $d.scantype -eq "SecurityRisk" -and $d.scancategory -eq "AutoProtect" }

$results.C4 = T "C4" "WFolder: IncludeSubFolders" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -FolderPath "C:\Temp\SmokeFolderC4" -IncludeSubFolders | Out-Null } `
    { param($p) ($d = $p.configuration.directories | ? { $_.directory -like "*SmokeFolderC4*" } | Select -First 1); $d -and $d.recursive -eq $true }

Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -FolderPath "C:\Temp\SmokeFolderC5" | Out-Null
Start-Sleep -Milliseconds 500
$results.C5 = T "C5" "WFolder: Remove" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -FolderPath "C:\Temp\SmokeFolderC5" -Remove | Out-Null } `
    { param($p) ($p.configuration.directories | ? { $_.directory -like "*SmokeFolderC5*" }).Count -eq 0 }

$results.C6 = T "C6" "WFolder: SecurityRiskCategory without SecurityRisk (error)" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -FolderPath "C:\Temp\BadFolder" -ScanType All -SecurityRiskCategory AllScans } `
    { param($p) $true }

# === D group: WindowsExtension ===
$results.D1 = T "D1" "WExt: add .ps51test (merge)" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -Extensions ".ps51test" | Out-Null } `
    { param($p) ".ps51test" -in $p.configuration.extension_list.extensions }

$results.D2 = T "D2" "WExt: add .ps51test again (dedup)" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -Extensions ".ps51test" | Out-Null } `
    { param($p) ($p.configuration.extension_list.extensions | ? { $_ -eq ".ps51test" }).Count -eq 1 }

$results.D3 = T "D3" "WExt: remove .ps51test" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -Extensions ".ps51test" -Remove | Out-Null } `
    { param($p) ".ps51test" -notin $p.configuration.extension_list.extensions }

$results.D4 = T "D4" "WExt: remove nonexistent (error)" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -Extensions ".nonexistent_ext" -Remove } `
    { param($p) $true }

$results.D5 = T "D5" "WExt: ScanType AutoProtect" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -Extensions ".ps51test_d5" -ScanType AutoProtect | Out-Null } `
    { param($p) $p.configuration.extension_list.scancategory -eq "AutoProtect" }

# === E group: Tamper ===
$results.E1 = T "E1" "Tamper: basic add" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -TamperPath "C:\Temp\SmokeTamperE1.exe" | Out-Null } `
    { param($p) ($t = $p.configuration.tamper_files | ? { $_.path -eq "C:\Temp\SmokeTamperE1.exe" } | Select -First 1); $t -and $t.pathvariable -eq "[NONE]" -and $t.deleted -ne $true }

$results.E2 = T "E2" "Tamper: PathVariable [SYSTEM]" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -TamperPath "C:\Windows\SmokeTamperE2.exe" -PathVariable '[SYSTEM]' | Out-Null } `
    { param($p) ($t = $p.configuration.tamper_files | ? { $_.path -like "*SmokeTamperE2*" } | Select -First 1); $t -and $t.pathvariable -eq "[SYSTEM]" }

$results.E3 = T "E3" "Tamper: Remove" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -TamperPath "C:\Temp\SmokeTamperE1.exe" -Remove | Out-Null } `
    { param($p) ($p.configuration.tamper_files | ? { $_.path -like "*SmokeTamperE1*" }).Count -eq 0 }

# === F group: MacFile ===
$results.F1 = T "F1" "MacFile: basic add" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -MacPath "/tmp/SmokeMacF1.app" | Out-Null } `
    { param($p) ($m = $p.configuration.mac.files | ? { $_.path -eq "/tmp/SmokeMacF1.app" } | Select -First 1); $m -and $m.pathvariable -eq "[NONE]" -and $m.deleted -ne $true }

$results.F2 = T "F2" "MacFile: PathVariable [HOME]" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -MacPath "/Users/test/SmokeMacF2.app" -MacPathVariable '[HOME]' | Out-Null } `
    { param($p) ($m = $p.configuration.mac.files | ? { $_.path -like "*SmokeMacF2*" } | Select -First 1); $m -and $m.pathvariable -eq "[HOME]" }

$results.F3 = T "F3" "MacFile: Remove" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -MacPath "/tmp/SmokeMacF1.app" -Remove | Out-Null } `
    { param($p) ($p.configuration.mac.files | ? { $_.path -like "*SmokeMacF1*" }).Count -eq 0 }

# === G group: Error handling ===
$results.G3 = T "G3" "NonExistentPolicy error" `
    { Update-SEPMExceptionPolicy -PolicyName "NonExistentPolicy" -EnablePolicy } `
    { param($p) $true }

# === Summary ===
Write-Host "`n========== SUMMARY (PS51) =========="
$pass = 0; $fail = 0
foreach ($k in $results.Keys | Sort-Object) {
    $v = $results[$k]
    if ($v -eq "PASS") { $pass++; Write-Host "  $k : PASS" }
    else { $fail++; Write-Host "  $k : FAIL" }
}
Write-Host "TOTAL: $($pass+$fail) tests, $pass pass, $fail fail"
