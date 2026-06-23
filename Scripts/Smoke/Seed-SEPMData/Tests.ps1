<#
.SYNOPSIS
    Shared smoke tests for Seed-SEPMData orchestrator.

.DESCRIPTION
    Dot-sourced by run.ps7.ps1 and run.ps51.ps1 after Common.ps1.
    Tests the orchestrator script with various -Categories parameters.
#>

Write-Host "=== Smoke: Seed-SEPMData ==="

$seedScript = Join-Path -Path $RepoRoot -ChildPath 'Scripts/Seed-SEPMData.ps1'

$results = @{}

# ── A1: -Categories Test ──
$results.A1 = & {
    try {
        Write-Host "--- Test: -Categories Test ---"
        $result = & $seedScript -Categories Test
        if (-not $result) { throw "no output from -Categories Test" }
        if (($result -match 'Framework ready').Count -eq 0) { throw "expected 'Framework ready', got: $result" }
        if (($result -match 'Force: False').Count -eq 0) { throw "expected 'Force: False', got: $result" }
        Write-Host "  VERDICT: PASS" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── A2: -Categories Test -Force ──
$results.A2 = & {
    try {
        Write-Host "--- Test: -Categories Test -Force ---"
        $result = & $seedScript -Categories Test -Force
        if (-not $result) { throw "no output from -Categories Test -Force" }
        if (($result -match 'Framework ready').Count -eq 0) { throw "expected 'Framework ready', got: $result" }
        if (($result -match 'Force: True').Count -eq 0) { throw "expected 'Force: True', got: $result" }
        Write-Host "  VERDICT: PASS" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── A3: No parameters (defaults to all) ──
$results.A3 = & {
    try {
        Write-Host "--- Test: No parameters ---"
        $result = & $seedScript
        if (-not $result) { throw "no output from no-params" }
        if (($result -match 'No categories implemented yet').Count -eq 0) { throw "expected 'No categories implemented yet', got: $result" }
        Write-Host "  VERDICT: PASS" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── A4: -Categories Groups (live seed) ──
$results.A4 = & {
    try {
        Write-Host "--- Test: -Categories Groups ---"
        $beforeCount = (Get-SEPMGroups).Count
        $result = & $seedScript -Categories Groups
        $afterCount = (Get-SEPMGroups).Count
        if (-not $result) { throw "no output from -Categories Groups" }
        if (($result -match 'Groups seeded:').Count -eq 0) { throw "expected seed count, got: $result" }
        # Groups may already be seeded (idempotent) — accept count staying same or increasing
        if ($afterCount -lt $beforeCount) { throw "group count decreased ($beforeCount -> $afterCount)" }
        $added = $afterCount - $beforeCount
        $status = if ($added -eq 0) { "idempotent (already seeded)" } else { "+$added" }
        Write-Host "  VERDICT: PASS (groups: $beforeCount -> $afterCount, $status)" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── A5: Groups Idempotency ──
$results.A5 = & {
    try {
        Write-Host "--- Test: Groups Idempotency ---"
        $beforeCount = (Get-SEPMGroups).Count
        $result = & $seedScript -Categories Groups
        $afterCount = (Get-SEPMGroups).Count
        if ($afterCount -ne $beforeCount) { throw "counts changed on re-run ($beforeCount -> $afterCount)" }
        Write-Host "  VERDICT: PASS (idempotent, $afterCount groups)" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── A6: -Categories Admins (live seed) ──
$results.A6 = & {
    try {
        Write-Host "--- Test: -Categories Admins ---"
        $beforeCount = (Get-SEPMAdmins).Count
        $result = & $seedScript -Categories Admins
        $afterCount = (Get-SEPMAdmins).Count
        if (-not $result) { throw "no output from -Categories Admins" }
        if (($result -match 'Admins seeded:').Count -eq 0) { throw "expected seed count, got: $result" }
        if ($afterCount -lt $beforeCount) { throw "admin count decreased ($beforeCount -> $afterCount)" }
        $added = $afterCount - $beforeCount
        $status = if ($added -eq 0) { "idempotent (already seeded)" } else { "+$added" }
        Write-Host "  VERDICT: PASS (admins: $beforeCount -> $afterCount, $status)" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── A7: Admins Idempotency ──
$results.A7 = & {
    try {
        Write-Host "--- Test: Admins Idempotency ---"
        $beforeCount = (Get-SEPMAdmins).Count
        $result = & $seedScript -Categories Admins
        $afterCount = (Get-SEPMAdmins).Count
        if ($afterCount -ne $beforeCount) { throw "counts changed on re-run ($beforeCount -> $afterCount)" }
        Write-Host "  VERDICT: PASS (idempotent, $afterCount admins)" -ForegroundColor Green
        "PASS"
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        "FAIL"
    }
}

# ── Summary ──
Write-Summary -Results $results -Label "Seed-SEPMData Smoke Tests"
