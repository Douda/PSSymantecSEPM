<#
.SYNOPSIS
    Exports all firewall policies as raw XML files, named after their SEPM policy name.

.DESCRIPTION
    Standalone export script (not part of the module). Leverages the built module for
    auth + transport:
      - Set-SEPMConfiguration / Set-SEPMAuthentication (saved creds or prompt)
      - Initialize-SEPMSession + Invoke-SepmApi (private, via module-scope invocation)

    API calls: 1x GET /policies/summary + 1x GET /policies/raw/fw/{id} per firewall policy.

    Output: <OutputDir>/firewall_policy_xml/<PolicyName>.xml
    Files contain the raw policy_xml payload from the API — no parsing, no re-serialization.

    Filenames use the exact policy name; only characters invalid in Windows filenames
    (and '/') are replaced with '-', and every rename is reported.

.EXAMPLE
    # From repo root, using saved SEPM configuration + credentials:
    pwsh -File Scripts/Export-FirewallPolicyXml.ps1

.EXAMPLE
    # Explicit target server, output to a specific directory:
    pwsh -File Scripts/Export-FirewallPolicyXml.ps1 -ServerAddress 172.20.0.2 -Port 8446 -OutputDir C:\fwexport
#>
[CmdletBinding()]
param(
    [string]$ServerAddress = '',
    [int]$Port = 0,
    [string]$OutputDir = (Get-Location).Path,
    [int]$DelayMs = 100
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path $repoRoot 'Output/PSSymantecSEPM/PSSymantecSEPM.psm1'
if (Test-Path $modulePath) {
    Import-Module $modulePath -Force
}
elseif (-not (Get-Module PSSymantecSEPM)) {
    throw "Built module not found at $modulePath and none imported. Build it first (see AGENTS.md)."
}
$mod = Get-Module PSSymantecSEPM
# Self-signed SEPM cert — Test-SEPMCertificate is disabled, bypass in module scope
& $mod { $script:SkipCert = $true }

if ($ServerAddress) {
    if ($Port) { Set-SEPMConfiguration -ServerAddress $ServerAddress -Port $Port }
    else { Set-SEPMConfiguration -ServerAddress $ServerAddress }
}
Set-SEPMAuthentication

$session = & $mod { Initialize-SEPMSession }

function Invoke-SepmGet {
    param([string]$Uri)
    & $mod { param($s, $u) Invoke-SepmApi -Method GET -Uri $u -Session $s } $session $Uri
}

function ConvertTo-SafePolicyFileName {
    param([string]$Name)
    # Windows-invalid filename chars + control chars -> '-'; valid names pass through untouched
    return ($Name -replace '[\\/:*?"<>|\x00-\x1F]', '-')
}

$summary = Invoke-SepmGet "$($session.BaseURLv1)/policies/summary"
$fw = @($summary.content | Where-Object { $_.policytype -eq 'fw' })
"Found $($fw.Count) firewall policies"
if ($fw.Count -eq 0) { throw 'No firewall policies in summary — check the target server.' }

$dir = Join-Path $OutputDir 'firewall_policy_xml'
New-Item -ItemType Directory -Path $dir -Force | Out-Null

$ok = 0
$failed = @()
$seen = @{}
foreach ($p in $fw) {
    if ($DelayMs -gt 0) { Start-Sleep -Milliseconds $DelayMs }
    try {
        $resp = Invoke-SepmGet "$($session.BaseURLv1)/policies/raw/fw/$($p.id)"
        $raw = $resp.policy_xml
        if (-not $raw) { throw 'Empty policy_xml in response' }

        $base = ConvertTo-SafePolicyFileName $p.name
        $fileName = "$base.xml"
        if ($seen[$fileName]) { $fileName = "${base}_$($p.id).xml" }  # name collision
        $seen[$fileName] = $true

        # WriteAllText: exact string, UTF-8 without BOM, no trailing newline
        [System.IO.File]::WriteAllText((Join-Path $dir $fileName), $raw)

        if ($base -ne $p.name) { "  renamed: '$($p.name)' -> $fileName" }
        "  {0,-60} {1,10} bytes" -f $fileName, $raw.Length
        $ok++
    }
    catch {
        "  FAILED: $($p.name) — $($_.Exception.Message)"
        $failed += $p.name
    }
}

""
"Done: $ok/$($fw.Count) firewall policies written to $dir"
if ($failed.Count -gt 0) { "Failed: $($failed -join '; ')" }
