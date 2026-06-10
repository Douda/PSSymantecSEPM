$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"
. "$RepoRoot\Common-PS51.ps1"

Write-Host "=== Smoke: Move-SEPClientGroup (PS5.1) ===" -ForegroundColor Yellow

$results = @{}

$s = Initialize-SEPMSession
$content = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/computers?pageSize=5&pageIndex=1&sort=COMPUTER_NAME" -Headers $s.Headers -SkipCert:$s.SkipCert
$computers = $content.content

if (-not $computers -or $computers.Count -eq 0) {
    $results.A1 = Skip "A1" "Move computer" "No computers found"
    $results.A2 = Skip "A2" "Move back" "No computers found"
    $results.A3 = Skip "A3" "Output type" "No computers found"
    $results.A4 = Skip "A4" "Output fields" "No computers found"
    $results.A5 = Skip "A5" "Error on invalid" "No computers for context"
} else {
    $srcComputer = $null
    foreach ($c in $computers) {
        $name = if ($c -is [hashtable]) { $c.computerName } else { $c.computerName }
        if ($name) { $srcComputer = $name; $srcGroupObj = if ($c -is [hashtable]) { $c.group } else { $c.group }; break }
    }

    if (-not $srcComputer) {
        $results.A1 = Skip "A1" "Move computer" "No valid computer name found"
        $results.A2 = Skip "A2" "Move back" "No valid computer name found"
        $results.A3 = Skip "A3" "Output type" "No valid computer name found"
        $results.A4 = Skip "A4" "Output fields" "No valid computer name found"
        $results.A5 = Skip "A5" "Error on invalid" "No valid computer name for context"
    } else {
        $srcGroup = if ($srcGroupObj -is [hashtable]) { $srcGroupObj.name } else { $srcGroupObj.name }
        $groups = @(Get-SEPMGroups | Where-Object { $_.fullPathName -match 'Workstations' } | Select-Object -First 1)
        $targetGroup = if ($groups.Count -gt 0) { $groups[0].fullPathName } else { 'My Company' }

        Write-Host "Moving '$srcComputer' from '$srcGroup' -> '$targetGroup'" -ForegroundColor Gray

        $results.A1 = T "A1" "Move computer" `
            { Move-SEPClientGroup -ComputerName $srcComputer -GroupName $targetGroup } `
            { param($r) $r -and $r.computerName }

        Start-Sleep -Seconds 1
        $results.A2 = T "A2" "Move back" `
            { Move-SEPClientGroup -ComputerName $srcComputer -GroupName $srcGroup } `
            { param($r) $r -and $r.computerName }

        $results.A3 = T "A3" "Output type" `
            {
                Start-Sleep -Seconds 1
                $r = Move-SEPClientGroup -ComputerName $srcComputer -GroupName $targetGroup
                Start-Sleep -Seconds 1
                Move-SEPClientGroup -ComputerName $srcComputer -GroupName $srcGroup | Out-Null
                $r.PSObject.TypeNames[0]
            } `
            { param($r) $r -eq 'SEPM.MoveClientGroupResponse' }

        $results.A4 = T "A4" "Output fields" `
            {
                Start-Sleep -Seconds 1
                $r = Move-SEPClientGroup -ComputerName $srcComputer -GroupName $targetGroup
                Start-Sleep -Seconds 1
                Move-SEPClientGroup -ComputerName $srcComputer -GroupName $srcGroup | Out-Null
                [bool]($r.computerName -and $r.targetGroup)
            } `
            { param($r) $r -eq $true }

        $results.A5 = T "A5" "Error on invalid" `
            {
                $errs = $null
                Move-SEPClientGroup -ComputerName 'NonExistentComputerXYZ' -GroupName $targetGroup -ErrorVariable errs -ErrorAction SilentlyContinue
                $errs.Count -gt 0
            } `
            { param($r) $r -eq $true }
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
