$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"
. "$RepoRoot\Common-PS51.ps1"

Write-Host "=== Smoke: New-SEPMGroup (PS5.1) ===" -ForegroundColor Yellow

$results = @{}
$testGroupName = "SmokeTest_Group_$(Get-Date -Format 'yyyyMMddHHmmss')"
$inheritGroupName = "SmokeTest_Inherit_$(Get-Date -Format 'yyyyMMddHHmmss')"
$descGroupName = "SmokeTest_Desc_$(Get-Date -Format 'yyyyMMddHHmmss')"

$results.A1 = T "A1" "Create group" `
    { New-SEPMGroup -GroupName $testGroupName -ParentGroup 'My Company' -Description 'Smoke test group' } `
    { param($r) $r -ne $null }

$results.A2 = T "A2" "Verify exists" `
    { [bool](Get-SEPMGroups | Where-Object { $_.name -eq $testGroupName }) } `
    { param($r) $r -eq $true }

$results.A3 = T "A3" "Create with inheritance" `
    { New-SEPMGroup -GroupName $inheritGroupName -ParentGroup 'My Company' -EnabledInheritance } `
    { param($r) $r -ne $null }

$results.A4 = T "A4" "Error on bad parent" `
    {
        $errs = $null
        New-SEPMGroup -GroupName 'BadGroup' -ParentGroup 'My Company\NonExistentParent123' -ErrorVariable errs -ErrorAction SilentlyContinue
        $errs.Count -gt 0
    } `
    { param($r) $r -eq $true }

$results.A5 = T "A5" "Create with description" `
    { New-SEPMGroup -GroupName $descGroupName -ParentGroup 'My Company' -Description 'Custom description' } `
    { param($r) $r -ne $null }

Write-Host "`n--- CLEANUP ---" -ForegroundColor Yellow
@($testGroupName, $inheritGroupName, $descGroupName) | ForEach-Object {
    try {
        Remove-SEPMGroup -GroupName $_ -ParentGroup 'My Company' -ErrorAction SilentlyContinue | Out-Null
        Write-Host "  Removed: $_" -ForegroundColor Gray
    } catch {
        Write-Host "  Failed to remove: $_" -ForegroundColor Yellow
    }
}

$pass = 0; $fail = 0; $skip = 0
foreach ($k in $results.Keys | Sort-Object) {
    $v = $results[$k]
    if ($v -eq "PASS") { $pass++; Write-Host "  $k : PASS" -ForegroundColor Green }
    elseif ($v -eq "SKIP") { $skip++; Write-Host "  $k : SKIP" -ForegroundColor Yellow }
    else { $fail++; Write-Host "  $k : FAIL" -ForegroundColor Red }
}
Write-Host "TOTAL: $($pass+$fail+$skip) tests, $pass pass, $fail fail, $skip skip" -ForegroundColor Yellow

if ($fail -gt 0) { Write-Error "Smoke tests failed: $fail failure(s)"; exit 1 }
