# Smoke: Move-SEPClientGroup (PS7)
$ErrorActionPreference = "Continue"
$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"

Write-Host "=== Smoke: Move-SEPClientGroup (PS7) ==="

$pass = 0; $fail = 0

# Discovery via direct API
$s = Initialize-SEPMSession
$content = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/computers?pageSize=5&pageIndex=1&sort=COMPUTER_NAME" -Headers $s.Headers -SkipCert:$s.SkipCert
$computers = $content.content

if (-not $computers -or $computers.Count -eq 0) {
    Write-Host "SKIP: No computers found" -ForegroundColor Yellow
    exit 0
}

$srcComputer = $null
foreach ($c in $computers) {
    $name = if ($c -is [hashtable]) { $c.computerName } else { $c.computerName }
    if ($name) { $srcComputer = $name; $srcGroupObj = if ($c -is [hashtable]) { $c.group } else { $c.group }; break }
}
if (-not $srcComputer) {
    Write-Host "SKIP: No valid computer name found" -ForegroundColor Yellow
    exit 0
}
$srcGroup = if ($srcGroupObj -is [hashtable]) { $srcGroupObj.name } else { $srcGroupObj.name }

# Get a target group
$groups = @(Get-SEPMGroups | Where-Object { $_.fullPathName -match 'Workstations' } | Select-Object -First 1)
$targetGroup = if ($groups.Count -gt 0) { $groups[0].fullPathName } else { 'My Company' }

Write-Host "Moving '$srcComputer' from '$srcGroup' -> '$targetGroup'" -ForegroundColor Gray

# Test 1: Move computer
try {
    $result = Move-SEPClientGroup -ComputerName $srcComputer -GroupName $targetGroup
    if ($result -and $result.computerName) {
        Write-Host "  T1: Move OK - PASS" -ForegroundColor Green; $pass++
    } else {
        Write-Host "  T1: FAIL" -ForegroundColor Red; $fail++
    }
} catch {
    Write-Host "  T1: FAIL - $($_.Exception.Message)" -ForegroundColor Red; $fail++
}

# Test 2: Move back
Start-Sleep -Seconds 1
try {
    $result = Move-SEPClientGroup -ComputerName $srcComputer -GroupName $srcGroup
    if ($result -and $result.computerName) {
        Write-Host "  T2: Move back OK - PASS" -ForegroundColor Green; $pass++
    } else {
        Write-Host "  T2: FAIL" -ForegroundColor Red; $fail++
    }
} catch {
    Write-Host "  T2: FAIL - $($_.Exception.Message)" -ForegroundColor Red; $fail++
}

# Test 3: Output type
try {
    Start-Sleep -Seconds 1
    $result = Move-SEPClientGroup -ComputerName $srcComputer -GroupName $targetGroup
    if ($result.PSObject.TypeNames[0] -eq 'SEPM.MoveClientGroupResponse') {
        Write-Host "  T3: Type OK - PASS" -ForegroundColor Green; $pass++
    } else {
        Write-Host "  T3: FAIL" -ForegroundColor Red; $fail++
    }
    Start-Sleep -Seconds 1
    Move-SEPClientGroup -ComputerName $srcComputer -GroupName $srcGroup | Out-Null
} catch {
    Write-Host "  T3: FAIL - $($_.Exception.Message)" -ForegroundColor Red; $fail++
}

# Test 4: Output fields
try {
    Start-Sleep -Seconds 1
    $result = Move-SEPClientGroup -ComputerName $srcComputer -GroupName $targetGroup
    if ($result.computerName -and $result.targetGroup) {
        Write-Host "  T4: Fields OK - PASS" -ForegroundColor Green; $pass++
    } else {
        Write-Host "  T4: FAIL" -ForegroundColor Red; $fail++
    }
    Start-Sleep -Seconds 1
    Move-SEPClientGroup -ComputerName $srcComputer -GroupName $srcGroup | Out-Null
} catch {
    Write-Host "  T4: FAIL - $($_.Exception.Message)" -ForegroundColor Red; $fail++
}

# Test 5: Invalid computer
try {
    $errors = $null
    Move-SEPClientGroup -ComputerName 'NonExistentComputerXYZ' -GroupName $targetGroup -ErrorVariable errors -ErrorAction SilentlyContinue
    if ($errors.Count -gt 0) {
        Write-Host "  T5: Error on invalid - PASS" -ForegroundColor Green; $pass++
    } else {
        Write-Host "  T5: FAIL" -ForegroundColor Red; $fail++
    }
} catch {
    Write-Host "  T5: FAIL - $($_.Exception.Message)" -ForegroundColor Red; $fail++
}

Write-Host "`n=== SUMMARY (PS7) ===" -ForegroundColor Yellow
Write-Host "TOTAL: $($pass+$fail) tests, $pass pass, $fail fail" -ForegroundColor Yellow
if ($fail -gt 0) { exit 1 }
