<#
.SYNOPSIS
    Platform-specific bootstrap for all PSSymantecSEPM smoke suites.

.DESCRIPTION
    Provides Initialize-SmokeBootstrap, which handles module import, certificate
    bypass, SEPM configuration, credential cleanup, and authentication — branching
    on $PSVersionTable.PSVersion.Major to support both PS 7+ (devcontainer/Linux)
    and PS 5.1 (Windows VM via WinRM).

    Dot-source this file from each suite's run.ps7.ps1 / run.ps51.ps1, then call:
        Initialize-SmokeBootstrap -RepoRoot $RepoRoot

    After bootstrap completes, dot-source Common.ps1 (pure function definitions)
    and the suite's Tests.ps1.

    PS 5.1 compatible — no ternary, no null-coalescing, no -SkipCertificateCheck.
#>

function Initialize-SmokeBootstrap {
    <#
    .SYNOPSIS
        Bootstrap the PSSymantecSEPM module and authenticate against the local SEPM VM.

    .PARAMETER RepoRoot
        Absolute path to the repository root. Verified with Test-Path before proceeding.

    .DESCRIPTION
        Branches on $PSVersionTable.PSVersion.Major internally:
          PS 7+ path: Set PSModulePath, import module from Output/, Set-SepmConfiguration,
                       clean stale credential/token files, authenticate.
          PS 5.1 path: ServicePointManager cert bypass + TLS 1.2, write config.json to
                       $env:APPDATA, import module from RepoRoot, authenticate.

        Auth credentials are embedded inside the function. Cmdlets fail naturally —
        no custom error wrapping beyond the RepoRoot guard.
    #>
    param(
        [string]$RepoRoot
    )

    if (-not (Test-Path $RepoRoot)) {
        throw "RepoRoot path '$RepoRoot' does not exist."
    }

    if ($PSVersionTable.PSVersion.Major -ge 7) {
        # ── PS 7+ path ──
        $OutputRoot = Join-Path -Path $RepoRoot -ChildPath 'Output'
        $env:PSModulePath = "$OutputRoot$([System.IO.Path]::PathSeparator)$env:PSModulePath"
        $ModulePath = Join-Path -Path $OutputRoot -ChildPath 'PSSymantecSEPM/PSSymantecSEPM.psm1'
        Import-Module $ModulePath -Force

        $SmokeModule = Get-Module PSSymantecSEPM
        & $SmokeModule { $script:SkipCert = $true }

        Set-SepmConfiguration -ServerAddress 'localhost' -Port 8446 -ErrorAction SilentlyContinue

        Remove-Item -Path "$HOME/.config/PSSymantecSEPM/creds.xml" -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$HOME/.local/share/PSSymantecSEPM/accessToken.xml" -Force -ErrorAction SilentlyContinue
    } else {
        # ── PS 5.1 path ──
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

        $cfg = "$env:APPDATA\PSSymantecSEPM\config.json"
        New-Item -ItemType Directory (Split-Path $cfg) -Force | Out-Null
        @{ port = 8446; ServerAddress = "localhost" } | ConvertTo-Json | Set-Content $cfg -Force

        $ModulePath = "$RepoRoot\PSSymantecSEPM\PSSymantecSEPM.psm1"
        Import-Module $ModulePath -Force
        $env:PSModulePath = "$RepoRoot;$env:PSModulePath"

        $SmokeModule = Get-Module PSSymantecSEPM
        & $SmokeModule { $script:SkipCert = $true }
    }

    # ── Authenticate (common to both platforms) ──
    $SmokeCredPassword = ConvertTo-SecureString -String 'MyComplexPassword1!' -AsPlainText -Force
    $SmokeCredential   = New-Object System.Management.Automation.PSCredential -ArgumentList 'admin', $SmokeCredPassword
    Set-SEPMAuthentication -Credential $SmokeCredential -ErrorAction SilentlyContinue
    Get-SEPMAccessToken | Out-Null
}
