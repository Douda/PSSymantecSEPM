# Smoke verification for Get-SEPMExceptionPolicy (PS7)
# Usage: pwsh -NoProfile -File Scripts/Smoke/Get-SEPMExceptionPolicy/batch.ps7.ps1

[CmdletBinding()]param()

$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"

Write-Host "=== Smoke: Get-SEPMExceptionPolicy (PS7) ===" -ForegroundColor Yellow

$results = @{}

# ── A1: Retrieve exception policy by name ──
$results.A1 = T "A1" "Get-SEPMExceptionPolicy by name returns full policy" `
    { Get-SEPMExceptionPolicy -PolicyName "Exceptions policy" } `
    { param($r)
        $r -ne $null -and
        $r.PSObject.TypeNames[0] -eq 'SEPM.ExceptionPolicy' -and
        $r.name -eq 'Exceptions policy' -and
        $null -ne $r.enabled -and
        $null -ne $r.configuration
    }

# ── A2: List files from exception policy ──
$results.A2 = T "A2" "Get-SEPMExceptionPolicy -List files returns flattened files" `
    { Get-SEPMExceptionPolicy -PolicyName "Exceptions policy" -List files } `
    { param($r)
        $r -ne $null -and
        $r.Count -ge 0
    }

# ── A3: List directories from exception policy ──
$results.A3 = T "A3" "Get-SEPMExceptionPolicy -List directories returns flattened dirs" `
    { Get-SEPMExceptionPolicy -PolicyName "Exceptions policy" -List directories } `
    { param($r)
        $null -ne $r -and
        $r.Count -ge 0
    }

# ── Summary ──
Write-Host "`n========== SUMMARY (PS7) ==========" -ForegroundColor Yellow
$pass = 0; $fail = 0
foreach ($k in $results.Keys | Sort-Object) {
    $v = $results[$k]
    if ($v -eq "PASS") { $pass++; Write-Host "  $k : PASS" -ForegroundColor Green }
    else { $fail++; Write-Host "  $k : FAIL" -ForegroundColor Red }
}
Write-Host "TOTAL: $($pass+$fail) tests, $pass pass, $fail fail" -ForegroundColor Yellow
