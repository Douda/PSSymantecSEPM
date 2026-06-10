$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"
. "$RepoRoot\Common-PS51.ps1"

Write-Host "=== Smoke: Get-SEPMVersion (PS5.1) ==="

$results = @{}

$results.A1 = T "A1" "returns version fields" `
    { Get-SEPMVersion } `
    { param($r) $r -ne $null -and $r.API_SEQUENCE -ne $null -and $r.API_VERSION -ne $null -and $r.version -ne $null }

$results.A2 = T "A2" "API_VERSION is a non-empty string" `
    { Get-SEPMVersion } `
    { param($r) $r.API_VERSION -is [string] -and $r.API_VERSION.Length -gt 0 }

$results.A3 = T "A3" "version is a non-empty string" `
    { Get-SEPMVersion } `
    { param($r) $r.version -is [string] -and $r.version.Length -gt 0 }

$pass = ($results.Values | Where-Object { $_ -eq "PASS" }).Count
$fail = ($results.Values | Where-Object { $_ -eq "FAIL" }).Count

Write-Host "`n=== SUMMARY: PS5.1 $pass PASS, $fail FAIL ==="

if ($fail -gt 0) {
    exit 1
}
