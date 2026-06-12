<#
.SYNOPSIS
    Shared smoke tests for Get-SEPMExceptionPolicy.

.DESCRIPTION
    Dot-sourced by run.ps7.ps1 and run.ps51.ps1 after Common.ps1.
    Covers: retrieve exception policy by name, list files, list directories.
#>

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

Write-Summary -Results $results -Label "Get-SEPMExceptionPolicy Smoke Tests"
