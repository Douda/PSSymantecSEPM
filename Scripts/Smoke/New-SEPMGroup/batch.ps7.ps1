# Smoke: New-SEPMGroup (PS7)
$ErrorActionPreference = "Continue"
$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"

Write-Host "=== Smoke: New-SEPMGroup (PS7) ==="
$pass = 0; $fail = 0
$testGroupName = "SmokeTest_Group_$(Get-Date -Format 'yyyyMMddHHmmss')"

# Test 1: Create group
try {
    $result = New-SEPMGroup -GroupName $testGroupName -ParentGroup 'My Company' -Description 'Smoke test group'
    if ($result -ne $null) {
        Write-Host "  T1: Create group - PASS" -ForegroundColor Green; $pass++
    } else {
        Write-Host "  T1: FAIL" -ForegroundColor Red; $fail++
    }
} catch {
    Write-Host "  T1: FAIL - $($_.Exception.Message)" -ForegroundColor Red; $fail++
}

# Test 2: Verify group exists via Get-SEPMGroups
try {
    $groups = Get-SEPMGroups | Where-Object { $_.name -eq $testGroupName }
    if ($groups) {
        Write-Host "  T2: Verify exists - PASS" -ForegroundColor Green; $pass++
    } else {
        Write-Host "  T2: FAIL - group not found" -ForegroundColor Red; $fail++
    }
} catch {
    Write-Host "  T2: FAIL - $($_.Exception.Message)" -ForegroundColor Red; $fail++
}

# Test 3: Create with EnabledInheritance
$inheritGroupName = "SmokeTest_Inherit_$(Get-Date -Format 'yyyyMMddHHmmss')"
try {
    $result = New-SEPMGroup -GroupName $inheritGroupName -ParentGroup 'My Company' -EnabledInheritance
    if ($result -ne $null) {
        Write-Host "  T3: Create with inheritance - PASS" -ForegroundColor Green; $pass++
    } else {
        Write-Host "  T3: FAIL" -ForegroundColor Red; $fail++
    }
} catch {
    Write-Host "  T3: FAIL - $($_.Exception.Message)" -ForegroundColor Red; $fail++
}

# Test 4: Invalid parent group
try {
    $errors = $null
    New-SEPMGroup -GroupName 'BadGroup' -ParentGroup 'My Company\NonExistentParent123' -ErrorVariable errors -ErrorAction SilentlyContinue
    if ($errors.Count -gt 0) {
        Write-Host "  T4: Error on bad parent - PASS" -ForegroundColor Green; $pass++
    } else {
        Write-Host "  T4: FAIL" -ForegroundColor Red; $fail++
    }
} catch {
    Write-Host "  T4: FAIL - $($_.Exception.Message)" -ForegroundColor Red; $fail++
}

# Test 5: Create with description
$descGroupName = "SmokeTest_Desc_$(Get-Date -Format 'yyyyMMddHHmmss')"
try {
    $result = New-SEPMGroup -GroupName $descGroupName -ParentGroup 'My Company' -Description 'Custom description'
    if ($result -ne $null) {
        Write-Host "  T5: Create with description - PASS" -ForegroundColor Green; $pass++
    } else {
        Write-Host "  T5: FAIL" -ForegroundColor Red; $fail++
    }
} catch {
    Write-Host "  T5: FAIL - $($_.Exception.Message)" -ForegroundColor Red; $fail++
}

# Cleanup
Write-Host "`n=== CLEANUP ===" -ForegroundColor Yellow
@($testGroupName, $inheritGroupName, $descGroupName) | ForEach-Object {
    try {
        Remove-SEPMGroup -GroupName $_ -ParentGroup 'My Company' -ErrorAction SilentlyContinue | Out-Null
        Write-Host "  Removed: $_" -ForegroundColor Gray
    } catch {
        Write-Host "  Failed to remove: $_" -ForegroundColor Yellow
    }
}

Write-Host "`n=== SUMMARY (PS7) ===" -ForegroundColor Yellow
Write-Host "TOTAL: $($pass+$fail) tests, $pass pass, $fail fail" -ForegroundColor Yellow
if ($fail -gt 0) { exit 1 }
