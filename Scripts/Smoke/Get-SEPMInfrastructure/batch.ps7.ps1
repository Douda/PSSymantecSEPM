# Smoke batch: infrastructure GET cmdlets (PS7)
# Covers: Get-SEPGUPList, Get-SEPMLicense, Get-SEPMDatabaseInfo, Get-SEPMLatestDefinition
# Usage: pwsh -NoProfile -File Scripts/Smoke/Get-SEPMInfrastructure/batch.ps7.ps1

$ErrorActionPreference = "Continue"

Import-Module ./Output/PSSymantecSEPM/PSSymantecSEPM.psm1 -Force
$mod = Get-Module PSSymantecSEPM
& $mod { $script:SkipCert = $true }

function T {
    param($Id, $Label, [ScriptBlock]$Action, [ScriptBlock]$Assert)
    Write-Host "--- $Id : $Label ---" -ForegroundColor Cyan
    try {
        $result = & $Action

        # Check for API error strings
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

# ── A1: Get-SEPGUPList ──
$results.A1 = T "A1" "Get-SEPGUPList" `
    { Get-SEPGUPList } `
    { param($r) ($null -eq $r) -or ($r -is [array] -or $r -is [hashtable]) }

# ── A2: Get-SEPMLicense ──
$results.A2 = T "A2" "Get-SEPMLicense" `
    { Get-SEPMLicense } `
    { param($r) $r -ne $null -and ($r -is [PSCustomObject] -or $r -is [hashtable]) }

# ── A3: Get-SEPMLicense -Summary ──
$results.A3 = T "A3" "Get-SEPMLicense -Summary" `
    { Get-SEPMLicense -Summary } `
    { param($r) $r -ne $null -and ($r -is [hashtable]) }

# ── A4: Get-SEPMDatabaseInfo ──
$results.A4 = T "A4" "Get-SEPMDatabaseInfo" `
    { Get-SEPMDatabaseInfo } `
    { param($r) $r -ne $null -and ($r -is [hashtable]) -and $r.database -ne $null -and $r.name -ne $null }

# ── A5: Get-SEPMLatestDefinition ──
$results.A5 = T "A5" "Get-SEPMLatestDefinition" `
    { Get-SEPMLatestDefinition } `
    { param($r) $r -ne $null -and ($r -is [hashtable]) -and $r.contentName -ne $null }

# === Summary ===
Write-Host "`n========== SUMMARY (PS7 Infrastructure) ==========" -ForegroundColor Yellow
$pass = 0; $fail = 0
foreach ($k in $results.Keys | Sort-Object) {
    $v = $results[$k]
    if ($v -eq "PASS") { $pass++; Write-Host "  $k : PASS" -ForegroundColor Green }
    else { $fail++; Write-Host "  $k : FAIL" -ForegroundColor Red }
}
Write-Host "TOTAL: $($pass+$fail) tests, $pass pass, $fail fail" -ForegroundColor Yellow
