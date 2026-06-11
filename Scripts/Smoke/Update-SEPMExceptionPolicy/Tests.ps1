<#
.SYNOPSIS
    Shared smoke tests for Update-SEPMExceptionPolicy.

.DESCRIPTION
    Dot-sourced by run.ps7.ps1 and run.ps51.ps1 after Common.ps1.
    Covers 7 test groups:
      A: Metadata (EnablePolicy, DisablePolicy, PolicyDescription, combined, conflict)
      B: WindowsFile (AllScans, Sonar, SecurityRisk, ApplicationControl, ExcludeChildProcesses, PathVariable, Remove, combined rule+metadata)
      C: WindowsFolder (ScanType, SecurityRiskCategory, IncludeSubFolders, Remove, error path)
      D: WindowsExtension (add, merge/dedup, remove, nonexistent error, ScanType)
      E: Tamper (add, PathVariable, Remove)
      F: MacFile (add, PathVariable, Remove)
      G: NonExistentPolicy error
#>

# ── Policy discovery ──
$s = Initialize-SEPMSession
$summary = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/policies/summary/exceptions" -Headers $s.Headers -SkipCert:$s.SkipCert
if (-not $summary.content -or $summary.content.Count -eq 0) {
    Write-Error "No exception policies found"
    exit 1
}
$POLICY_NAME = $summary.content[0].name
$POLICY_ID   = $summary.content[0].id
Write-Host "Policy: $POLICY_NAME ($POLICY_ID)" -ForegroundColor Gray

function Get-PolicyState {
    <#
    .SYNOPSIS
        Fetches current policy state via Invoke-SepmApi (v2 API).
        Returns deserialized object.
    #>
    $s = Initialize-SEPMSession
    return Invoke-SepmApi -Method GET `
        -Uri "$($s.BaseURLv2)/policies/exceptions/$POLICY_ID" `
        -Headers $s.Headers `
        -SkipCert:$true
}

# ── Shared mutation test parameters ──
# All mutation tests use -AssertTarget to verify ground truth via the API
# and -SleepMs to give SEPM time to process each PATCH.
$SMOKE_SLEEP = 1500
$SMOKE_ASSERT = { Get-PolicyState }

# ── Save original state for restore ──
$originalPolicy = Get-PolicyState
$ORIGINAL_ENABLED = if ($originalPolicy.enabled -is [bool]) { $originalPolicy.enabled } else { $originalPolicy.enabled -eq $true }
$ORIGINAL_DESC = $originalPolicy.desc

$results = @{}

# ═══════════════════════════════════════════════
# Group A: Metadata
# ═══════════════════════════════════════════════

$results.A1 = T "A1" "EnablePolicy" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -EnablePolicy } `
    { param($p) $p.enabled -eq $true } `
    -SleepMs $SMOKE_SLEEP -AssertTarget $SMOKE_ASSERT

$results.A2 = T "A2" "DisablePolicy" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -DisablePolicy } `
    { param($p) $p.enabled -eq $false } `
    -SleepMs $SMOKE_SLEEP -AssertTarget $SMOKE_ASSERT

$results.A3 = T "A3" "PolicyDescription" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -EnablePolicy -PolicyDescription "desc-A3" } `
    { param($p) $p.enabled -eq $true -and $p.desc -eq "desc-A3" } `
    -SleepMs $SMOKE_SLEEP -AssertTarget $SMOKE_ASSERT

$results.A4 = T "A4" "Enable+Description" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -EnablePolicy -PolicyDescription "desc-A4" } `
    { param($p) $p.enabled -eq $true -and $p.desc -eq "desc-A4" } `
    -SleepMs $SMOKE_SLEEP -AssertTarget $SMOKE_ASSERT

$results.A5 = T "A5" "Enable+Disable (error)" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -EnablePolicy -DisablePolicy } `
    { param($p) $true } `
    -ExpectedError "EnablePolicy.*DisablePolicy"

# ═══════════════════════════════════════════════
# Group B: WindowsFile exceptions
# ═══════════════════════════════════════════════

$results.B1 = T "B1" "WF: no scan (default AllScans)" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -Path "C:\Temp\SmokeB1.exe" } `
    { param($p) ($f = $p.configuration.files | ? { $_.path -eq "C:\Temp\SmokeB1.exe" } | Select -First 1); $f -and $f.sonar -eq $true -and $f.securityrisk -eq $true -and $f.applicationcontrol -eq $true -and $f.scancategory -eq "AllScans" } `
    -SleepMs $SMOKE_SLEEP -AssertTarget $SMOKE_ASSERT

$results.B2 = T "B2" "WF: explicit AllScans" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -Path "C:\Temp\SmokeB2.exe" -AllScans } `
    { param($p) ($f = $p.configuration.files | ? { $_.path -eq "C:\Temp\SmokeB2.exe" } | Select -First 1); $f -and $f.sonar -and $f.securityrisk -and $f.applicationcontrol -and $f.scancategory -eq "AllScans" } `
    -SleepMs $SMOKE_SLEEP -AssertTarget $SMOKE_ASSERT

$results.B3 = T "B3" "WF: Sonar only" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -Path "C:\Temp\SmokeB3.exe" -Sonar } `
    { param($p) ($f = $p.configuration.files | ? { $_.path -eq "C:\Temp\SmokeB3.exe" } | Select -First 1); $f -and $f.sonar -eq $true -and $f.securityrisk -ne $true -and $f.applicationcontrol -ne $true } `
    -SleepMs $SMOKE_SLEEP -AssertTarget $SMOKE_ASSERT

$results.B4 = T "B4" "WF: SecurityRisk AutoProtect" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -Path "C:\Temp\SmokeB4.exe" -SecurityRiskCategory AutoProtect } `
    { param($p) ($f = $p.configuration.files | ? { $_.path -eq "C:\Temp\SmokeB4.exe" } | Select -First 1); $f -and $f.securityrisk -eq $true -and $f.scancategory -eq "AutoProtect" -and $f.sonar -ne $true } `
    -SleepMs $SMOKE_SLEEP -AssertTarget $SMOKE_ASSERT

$results.B5 = T "B5" "WF: ApplicationControl only" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -Path "C:\Temp\SmokeB5.exe" -ApplicationControl } `
    { param($p) ($f = $p.configuration.files | ? { $_.path -eq "C:\Temp\SmokeB5.exe" } | Select -First 1); $f -and $f.applicationcontrol -eq $true -and $f.sonar -ne $true -and $f.securityrisk -ne $true } `
    -SleepMs $SMOKE_SLEEP -AssertTarget $SMOKE_ASSERT

$results.B6 = T "B6" "WF: AppCtrl + ExcludeChildProcesses" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -Path "C:\Temp\SmokeB6.exe" -ApplicationControl -ExcludeChildProcesses } `
    { param($p) ($f = $p.configuration.files | ? { $_.path -eq "C:\Temp\SmokeB6.exe" } | Select -First 1); $f -and $f.applicationcontrol -eq $true -and $f.recursive -eq $true } `
    -SleepMs $SMOKE_SLEEP -AssertTarget $SMOKE_ASSERT

$results.B7 = T "B7" "WF: Sonar + AppCtrl" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -Path "C:\Temp\SmokeB7.exe" -Sonar -ApplicationControl } `
    { param($p) ($f = $p.configuration.files | ? { $_.path -eq "C:\Temp\SmokeB7.exe" } | Select -First 1); $f -and $f.sonar -and $f.applicationcontrol -and $f.securityrisk -ne $true } `
    -SleepMs $SMOKE_SLEEP -AssertTarget $SMOKE_ASSERT

$results.B8 = T "B8" "WF: Sonar + SecurityRisk ScheduledAndOndemand" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -Path "C:\Temp\SmokeB8.exe" -Sonar -SecurityRiskCategory ScheduledAndOndemand } `
    { param($p) ($f = $p.configuration.files | ? { $_.path -eq "C:\Temp\SmokeB8.exe" } | Select -First 1); $f -and $f.sonar -and $f.securityrisk -and $f.scancategory -eq "ScheduledAndOndemand" } `
    -SleepMs $SMOKE_SLEEP -AssertTarget $SMOKE_ASSERT

$results.B9 = T "B9" "WF: PathVariable [SYSTEM]" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -Path "C:\Windows\SmokeB9.exe" -PathVariable '[SYSTEM]' } `
    { param($p) ($f = $p.configuration.files | ? { $_.path -like "*SmokeB9.exe" } | Select -First 1); $f -and $f.pathvariable -eq "[SYSTEM]" } `
    -SleepMs $SMOKE_SLEEP -AssertTarget $SMOKE_ASSERT

# B10: pre-add target, then remove it
Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -Path "C:\Temp\SmokeB10.exe" -AllScans | Out-Null
Start-Sleep -Milliseconds 500
$results.B10 = T "B10" "WF: Remove" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -Path "C:\Temp\SmokeB10.exe" -Remove } `
    { param($p) ($p.configuration.files | ? { $_.path -like "*SmokeB10.exe" }).Count -eq 0 } `
    -SleepMs $SMOKE_SLEEP -AssertTarget $SMOKE_ASSERT

# B12: rule + metadata
$results.B12 = T "B12" "WF: AllScans + EnablePolicy" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -Path "C:\Temp\SmokeB12.exe" -AllScans -EnablePolicy } `
    { param($p) ($f = $p.configuration.files | ? { $_.path -eq "C:\Temp\SmokeB12.exe" } | Select -First 1); $p.enabled -eq $true -and $f -and $f.sonar -and $f.securityrisk -and $f.applicationcontrol } `
    -SleepMs $SMOKE_SLEEP -AssertTarget $SMOKE_ASSERT

$results.B13 = T "B13" "WF: AllScans + PolicyDescription" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -Path "C:\Temp\SmokeB13.exe" -AllScans -PolicyDescription "desc-B13" } `
    { param($p) ($f = $p.configuration.files | ? { $_.path -eq "C:\Temp\SmokeB13.exe" } | Select -First 1); $p.desc -eq "desc-B13" -and $f -and $f.sonar } `
    -SleepMs $SMOKE_SLEEP -AssertTarget $SMOKE_ASSERT

# ═══════════════════════════════════════════════
# Group C: WindowsFolder exceptions
# ═══════════════════════════════════════════════

$results.C1 = T "C1" "WFolder: default All" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -FolderPath "C:\Temp\SmokeFolderC1" } `
    { param($p) ($d = $p.configuration.directories | ? { $_.directory -like "*SmokeFolderC1*" } | Select -First 1); $d -and $d.scantype -eq "All" } `
    -SleepMs $SMOKE_SLEEP -AssertTarget $SMOKE_ASSERT

$results.C2 = T "C2" "WFolder: ScanType SONAR" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -FolderPath "C:\Temp\SmokeFolderC2" -ScanType SONAR } `
    { param($p) ($d = $p.configuration.directories | ? { $_.directory -like "*SmokeFolderC2*" } | Select -First 1); $d -and $d.scantype -eq "SONAR" } `
    -SleepMs $SMOKE_SLEEP -AssertTarget $SMOKE_ASSERT

$results.C3 = T "C3" "WFolder: SecurityRisk + AutoProtect" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -FolderPath "C:\Temp\SmokeFolderC3" -ScanType SecurityRisk -SecurityRiskCategory AutoProtect } `
    { param($p) ($d = $p.configuration.directories | ? { $_.directory -like "*SmokeFolderC3*" } | Select -First 1); $d -and $d.scantype -eq "SecurityRisk" -and $d.scancategory -eq "AutoProtect" } `
    -SleepMs $SMOKE_SLEEP -AssertTarget $SMOKE_ASSERT

$results.C4 = T "C4" "WFolder: IncludeSubFolders" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -FolderPath "C:\Temp\SmokeFolderC4" -IncludeSubFolders } `
    { param($p) ($d = $p.configuration.directories | ? { $_.directory -like "*SmokeFolderC4*" } | Select -First 1); $d -and $d.recursive -eq $true } `
    -SleepMs $SMOKE_SLEEP -AssertTarget $SMOKE_ASSERT

# C5: pre-add folder, then remove it
Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -FolderPath "C:\Temp\SmokeFolderC5" | Out-Null
Start-Sleep -Milliseconds 500
$results.C5 = T "C5" "WFolder: Remove" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -FolderPath "C:\Temp\SmokeFolderC5" -Remove } `
    { param($p) ($p.configuration.directories | ? { $_.directory -like "*SmokeFolderC5*" }).Count -eq 0 } `
    -SleepMs $SMOKE_SLEEP -AssertTarget $SMOKE_ASSERT

$results.C6 = T "C6" "WFolder: SecurityRiskCategory without SecurityRisk (error)" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -FolderPath "C:\Temp\BadFolder" -ScanType All -SecurityRiskCategory AllScans } `
    { param($p) $true } `
    -ExpectedError "SecurityRiskCategory.*ScanType"

# ═══════════════════════════════════════════════
# Group D: WindowsExtension exceptions
# ═══════════════════════════════════════════════

function Invoke-BootstrapExtensionList {
    <#
    .SYNOPSIS
        Seed extension_list with dummy entries so the SEPM API accepts subsequent
        extension mutations. Two entries prevent a PS scalar-unrolling edge case.
        Returns $true if the bootstrap was performed, $false if already populated.
    #>
    param([string]$Label)
    $state = Get-PolicyState
    if ($state.configuration.extension_list) {
        return $false
    }
    Write-Host "  Bootstrapping extension_list ($Label)..." -ForegroundColor Gray
    $body = @{
        configuration = @{
            extension_list = @{
                scancategory = 'AllScans'
                extensions   = @('.smoke_bootstrap_d1', '.smoke_bootstrap_d2')
            }
        }
    }
    $s = Initialize-SEPMSession
    Invoke-SepmApi -Method PATCH `
        -Uri "$($s.BaseURLv2)/policies/exceptions/$POLICY_ID" `
        -Headers $s.Headers -SkipCert:$s.SkipCert `
        -Body (ConvertTo-Json -InputObject $body -Depth 5 -Compress) `
        -ContentType 'application/json' `
        -ErrorAction SilentlyContinue | Out-Null
    return $true
}

$BOOTSTRAP_EXT = Invoke-BootstrapExtensionList -Label 'pre-D1'

$results.D1 = T "D1" "WExt: add .smoketest (merge)" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -Extensions ".smoketest" } `
    { param($p) ".smoketest" -in $p.configuration.extension_list.extensions -and $p.configuration.extension_list.scancategory -eq "AllScans" } `
    -SleepMs $SMOKE_SLEEP -AssertTarget $SMOKE_ASSERT

$results.D2 = T "D2" "WExt: add .smoketest again (dedup)" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -Extensions ".smoketest" } `
    { param($p) ($p.configuration.extension_list.extensions | ? { $_ -eq ".smoketest" }).Count -eq 1 } `
    -SleepMs $SMOKE_SLEEP -AssertTarget $SMOKE_ASSERT

$results.D3 = T "D3" "WExt: remove .smoketest" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -Extensions ".smoketest" -Remove } `
    { param($p) ".smoketest" -notin $p.configuration.extension_list.extensions } `
    -SleepMs $SMOKE_SLEEP -AssertTarget $SMOKE_ASSERT

$results.D4 = T "D4" "WExt: remove nonexistent (error)" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -Extensions ".nonexistent_ext" -Remove } `
    { param($p) $true } `
    -ExpectedError "not found"

# D3 Remove may leave extension_list empty (SEPM API quirk). Re-bootstrap before D5.
if ($BOOTSTRAP_EXT) {
    Invoke-BootstrapExtensionList -Label 'post-D3' | Out-Null
    Start-Sleep -Milliseconds 500
}

$results.D5 = T "D5" "WExt: ScanType AutoProtect" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -Extensions ".smoketest_d5" -ScanType AutoProtect } `
    { param($p) $p.configuration.extension_list.scancategory -eq "AutoProtect" -and ".smoketest_d5" -in $p.configuration.extension_list.extensions } `
    -SleepMs $SMOKE_SLEEP -AssertTarget $SMOKE_ASSERT

# ═══════════════════════════════════════════════
# Group E: Tamper files
# ═══════════════════════════════════════════════

$results.E1 = T "E1" "Tamper: basic add" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -TamperPath "C:\Temp\SmokeTamperE1.exe" } `
    { param($p) ($t = $p.configuration.tamper_files | ? { $_.path -eq "C:\Temp\SmokeTamperE1.exe" } | Select -First 1); $t -and $t.pathvariable -eq "[NONE]" -and $t.deleted -ne $true } `
    -SleepMs $SMOKE_SLEEP -AssertTarget $SMOKE_ASSERT

$results.E2 = T "E2" "Tamper: PathVariable [SYSTEM]" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -TamperPath "C:\Windows\SmokeTamperE2.exe" -PathVariable '[SYSTEM]' } `
    { param($p) ($t = $p.configuration.tamper_files | ? { $_.path -like "*SmokeTamperE2.exe" } | Select -First 1); $t -and $t.pathvariable -eq "[SYSTEM]" } `
    -SleepMs $SMOKE_SLEEP -AssertTarget $SMOKE_ASSERT

$results.E3 = T "E3" "Tamper: Remove" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -TamperPath "C:\Temp\SmokeTamperE1.exe" -Remove } `
    { param($p) ($p.configuration.tamper_files | ? { $_.path -like "*SmokeTamperE1*" }).Count -eq 0 } `
    -SleepMs $SMOKE_SLEEP -AssertTarget $SMOKE_ASSERT

# ═══════════════════════════════════════════════
# Group F: MacFile exceptions
# ═══════════════════════════════════════════════

$results.F1 = T "F1" "MacFile: basic add" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -MacPath "/tmp/SmokeMacF1.app" } `
    { param($p) ($m = $p.configuration.mac.files | ? { $_.path -eq "/tmp/SmokeMacF1.app" } | Select -First 1); $m -and $m.pathvariable -eq "[NONE]" -and $m.deleted -ne $true } `
    -SleepMs $SMOKE_SLEEP -AssertTarget $SMOKE_ASSERT

$results.F2 = T "F2" "MacFile: PathVariable [HOME]" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -MacPath "/Users/test/SmokeMacF2.app" -MacPathVariable '[HOME]' } `
    { param($p) ($m = $p.configuration.mac.files | ? { $_.path -like "*SmokeMacF2.app" } | Select -First 1); $m -and $m.pathvariable -eq "[HOME]" } `
    -SleepMs $SMOKE_SLEEP -AssertTarget $SMOKE_ASSERT

$results.F3 = T "F3" "MacFile: Remove" `
    { Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -MacPath "/tmp/SmokeMacF1.app" -Remove } `
    { param($p) ($p.configuration.mac.files | ? { $_.path -like "*SmokeMacF1*" }).Count -eq 0 } `
    -SleepMs $SMOKE_SLEEP -AssertTarget $SMOKE_ASSERT

# ═══════════════════════════════════════════════
# Group G: Error handling
# ═══════════════════════════════════════════════

$results.G3 = T "G3" "NonExistentPolicy error" `
    { Update-SEPMExceptionPolicy -PolicyName "NonExistentPolicy" -EnablePolicy } `
    { param($p) $true } `
    -ExpectedError "not found"

# ═══════════════════════════════════════════════
# Restore policy to original state
# ═══════════════════════════════════════════════

Write-Host "`n========== RESTORE ==========" -ForegroundColor Yellow

# Use direct Invoke-SepmApi to restore only metadata fields without affecting
# configuration (the Default parameter set would PATCH without configuration,
# which the SEPM API may interpret as clearing it).
function Invoke-RestorePolicyMetadata {
    param([bool]$Enabled, [string]$Description)
    $body = @{ enabled = $Enabled; desc = $Description }
    $s = Initialize-SEPMSession
    Invoke-SepmApi -Method PATCH `
        -Uri "$($s.BaseURLv2)/policies/exceptions/$POLICY_ID" `
        -Headers $s.Headers -SkipCert:$s.SkipCert `
        -Body (ConvertTo-Json -InputObject $body -Depth 3 -Compress) `
        -ContentType 'application/json' `
        -ErrorAction SilentlyContinue | Out-Null
}

if ($ORIGINAL_ENABLED) {
    $descToRestore = if ($ORIGINAL_DESC.Length -gt 1024) { $ORIGINAL_DESC.Substring(0, 1024) } else { $ORIGINAL_DESC }
    Invoke-RestorePolicyMetadata -Enabled $true -Description $descToRestore
} else {
    Invoke-RestorePolicyMetadata -Enabled $false -Description $ORIGINAL_DESC
}
Start-Sleep -Milliseconds 500

$finalState = Get-PolicyState

# Purge Smoke files
$smokeFiles = @($finalState.configuration.files | Where-Object { $_.path -match 'Smoke' })
foreach ($f in $smokeFiles) {
    Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -Path $f.path -Remove -ErrorAction SilentlyContinue | Out-Null
    Start-Sleep -Milliseconds 200
}
Write-Host "  Files removed: $($smokeFiles.Count)" -ForegroundColor Gray

# Purge Smoke directories
$smokeDirs = @($finalState.configuration.directories | Where-Object { $_.directory -match 'Smoke' })
foreach ($d in $smokeDirs) {
    Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -FolderPath $d.directory -Remove -ErrorAction SilentlyContinue | Out-Null
    Start-Sleep -Milliseconds 200
}
Write-Host "  Directories removed: $($smokeDirs.Count)" -ForegroundColor Gray

# Purge Smoke extensions (remove individually, skip if none remain)
$el = $finalState.configuration.extension_list
if ($el -and $el.extensions) {
    $smokeExts = @($el.extensions | Where-Object { $_ -match 'smoke' })
    foreach ($e in $smokeExts) {
        Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -Extensions $e -Remove -ErrorAction SilentlyContinue | Out-Null
        Start-Sleep -Milliseconds 200
    }
    Write-Host "  Extensions removed: $($smokeExts.Count)" -ForegroundColor Gray
}

# Purge Smoke tamper files
$smokeTamper = @($finalState.configuration.tamper_files | Where-Object { $_.path -match 'Smoke' })
foreach ($t in $smokeTamper) {
    Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -TamperPath $t.path -Remove -ErrorAction SilentlyContinue | Out-Null
    Start-Sleep -Milliseconds 200
}
Write-Host "  Tamper files removed: $($smokeTamper.Count)" -ForegroundColor Gray

# Purge Smoke Mac files
if ($finalState.configuration.mac -and $finalState.configuration.mac.files) {
    $smokeMac = @($finalState.configuration.mac.files | Where-Object { $_.path -match 'Smoke' })
    foreach ($m in $smokeMac) {
        Update-SEPMExceptionPolicy -PolicyName $POLICY_NAME -MacPath $m.path -Remove -ErrorAction SilentlyContinue | Out-Null
        Start-Sleep -Milliseconds 200
    }
    Write-Host "  Mac files removed: $($smokeMac.Count)" -ForegroundColor Gray
}

# Verify cleanup
$check = Get-PolicyState
$remainingSmoke = @($check.configuration.files | Where-Object { $_.path -match 'Smoke' }).Count +
                  @($check.configuration.directories | Where-Object { $_.directory -match 'Smoke' }).Count +
                  @($check.configuration.tamper_files | Where-Object { $_.path -match 'Smoke' }).Count
# Note: extensions are excluded from the count due to a SEPM API limitation —
# removing the last extension from extension_list is rejected by the API.
# The bootstrap extension (if any) may persist but does not affect policy function.
if ($remainingSmoke -eq 0) {
    Write-Host "  Policy restored: clean (0 Smoke artifacts)" -ForegroundColor Green
} else {
    Write-Host "  Policy restored: $remainingSmoke Smoke artifacts remain (extensions may persist)" -ForegroundColor Yellow
}

# ═══════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════
Write-Summary -Results $results -Label "Update-SEPMExceptionPolicy"
