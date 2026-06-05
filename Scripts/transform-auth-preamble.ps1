# Transform auth preamble in all Public cmdlets (except Get-SEPMAccessToken)
param(
    [string]$SourceDir = "$PSScriptRoot/../Source/Public",
    [switch]$DryRun
)

$files = Get-ChildItem -Path $SourceDir -Filter '*.ps1' | Where-Object { 
    $_.Name -ne 'Get-SEPMAccessToken.ps1' -and
    $_.Name -ne 'zz_Initialize-SepmConfiguration.ps1'
} | Where-Object {
    (Get-Content $_.FullName -Raw) -match 'Test-SEPMAccessToken'
}

Write-Host "Found $($files.Count) files to transform"

# The exact auth preamble (ends at "        }")
$preamble = @'
        # initialize the configuration
        $test_token = Test-SEPMAccessToken
        if (-not $test_token) {
            Get-SEPMAccessToken | Out-Null
        }
        if ($SkipCertificateCheck) {
            $script:SkipCert = $true
        }
'@

# The headers block (two variants: with and without trailing blank line)
$headersBlock = @'
        $headers = @{
            "Authorization" = "Bearer " + $script:accessToken.token
            "Content"       = 'application/json'
        }
'@

# Special case: Get-SEPMIpsPolicy has tabs
$ipsPreamble = @'
		        # initialize the configuration
        $test_token = Test-SEPMAccessToken
        if (-not $test_token) {
            Get-SEPMAccessToken | Out-Null
        }
        if ($SkipCertificateCheck) {
            $script:SkipCert = $true
        }
'@

$replacement = '        $session = Initialize-SEPMSession -SkipCertificateCheck:$SkipCertificateCheck'

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw
    $original = $content
    $name = $file.Name

    # Step 1: Replace auth preamble
    # Try with trailing blank line first, then without
    if ($content.Contains($preamble + "`n`n")) {
        $content = $content.Replace($preamble + "`n`n", "$replacement`n")
        Write-Host "  $name : preamble+blank replaced"
    } elseif ($content.Contains($preamble + "`n")) {
        $content = $content.Replace($preamble + "`n", "$replacement`n")
        Write-Host "  $name : preamble replaced"
    } elseif ($content.Contains($ipsPreamble)) {
        $content = $content.Replace($ipsPreamble, "$replacement`n")
        Write-Host "  $name : ips preamble replaced"
    } else {
        Write-Host "  $name : WARNING - preamble not matched!"
        continue
    }

    # Step 2: Replace $script:BaseURLv1/v2 in URI assignments
    $content = $content.Replace('$URI = $script:BaseURLv1', '$URI = $session.BaseURLv1')
    $content = $content.Replace('$URI = $script:BaseURLv2', '$URI = $session.BaseURLv2')

    # Step 3: Remove $headers construction block (try both with and without trailing newline)
    if ($content.Contains($headersBlock + "`n`n")) {
        $content = $content.Replace($headersBlock + "`n`n", "`n")
    } elseif ($content.Contains($headersBlock + "`n")) {
        $content = $content.Replace($headersBlock + "`n", "")
    }

    # Step 4: Replace all $headers references with $session.Headers
    $content = $content.Replace('$headers', '$session.Headers')

    # Step 5: Replace remaining $script:BaseURLv1/v2 (not in URI assignments)
    $content = $content.Replace('$script:BaseURLv1', '$session.BaseURLv1')
    $content = $content.Replace('$script:BaseURLv2', '$session.BaseURLv2')

    if ($content -ne $original) {
        if (-not $DryRun) {
            Set-Content -Path $file.FullName -Value $content -NoNewline
            Write-Host "  $name : SAVED"
        } else {
            Write-Host "  $name : would save (dry run)"
        }
    } else {
        Write-Host "  $name : no changes"
    }
}

Write-Host "Done."
