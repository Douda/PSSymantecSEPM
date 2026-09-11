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
          PS 7+ path: Set PSModulePath, import module from Output/, Set-SEPMConfiguration,
                       clean stale credential/token files, authenticate.
          PS 5.1 path: ServicePointManager cert bypass + TLS 1.2, write config.json to
                       $env:APPDATA, import module from RepoRoot, authenticate.

        Auth comes from the environment, so credentials can be rotated without editing this
        file: SEPM_USER, SEPM_PASS, SEPM_HOST and SEPM_PORT. Each falls back to the values
        that work against the local dev VM. A failed authentication stops the run and names
        the variables to set.
    #>
    param(
        [string]$RepoRoot
    )

    if (-not (Test-Path $RepoRoot)) {
        throw "RepoRoot path '$RepoRoot' does not exist."
    }

    # ── SEPM endpoint + credentials (env first, local dev defaults second) ──
    # The VM's own address differs by platform: from the devcontainer the container's docker
    # bridge address is what routes to the VM, while a process already on the VM uses loopback.
    $SmokeDefaultHost = '172.20.0.2'
    if ($PSVersionTable.PSVersion.Major -lt 7) { $SmokeDefaultHost = 'localhost' }

    $SepmHost = $env:SEPM_HOST
    if (-not $SepmHost) { $SepmHost = $SmokeDefaultHost }
    $SepmPort = 8446
    if ($env:SEPM_PORT) { $SepmPort = [int]$env:SEPM_PORT }
    $SepmUser = $env:SEPM_USER
    if (-not $SepmUser) { $SepmUser = 'sepm_api' }
    $SepmPass = $env:SEPM_PASS
    if (-not $SepmPass) { $SepmPass = 'Aurelien1!' }

    if ($PSVersionTable.PSVersion.Major -ge 7) {
        # ── PS 7+ path ──
        $OutputRoot = Join-Path -Path $RepoRoot -ChildPath 'Output'
        $env:PSModulePath = "$OutputRoot$([System.IO.Path]::PathSeparator)$env:PSModulePath"
        $ModulePath = Join-Path -Path $OutputRoot -ChildPath 'PSSymantecSEPM/PSSymantecSEPM.psm1'
        Import-Module $ModulePath -Force

        $SmokeModule = Get-Module PSSymantecSEPM
        & $SmokeModule { $script:SkipCert = $true }

        Set-SEPMConfiguration -ServerAddress $SepmHost -Port $SepmPort -ErrorAction SilentlyContinue

        Remove-Item -Path "$HOME/.config/PSSymantecSEPM/creds.xml" -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$HOME/.local/share/PSSymantecSEPM/accessToken.xml" -Force -ErrorAction SilentlyContinue
    } else {
        # ── PS 5.1 path ──
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

        $cfg = "$env:APPDATA\PSSymantecSEPM\config.json"
        New-Item -ItemType Directory (Split-Path $cfg) -Force | Out-Null
        @{ port = $SepmPort; ServerAddress = $SepmHost } | ConvertTo-Json | Set-Content $cfg -Force

        # A cached token outlives a credential rotation, so drop it here as the PS 7 path does.
        Remove-Item -Path "$env:LOCALAPPDATA\PSSymantecSEPM\accessToken.xml" -Force -ErrorAction SilentlyContinue

        $ModulePath = "$RepoRoot\PSSymantecSEPM\PSSymantecSEPM.psm1"
        Import-Module $ModulePath -Force
        $env:PSModulePath = "$RepoRoot;$env:PSModulePath"

        $SmokeModule = Get-Module PSSymantecSEPM
        & $SmokeModule { $script:SkipCert = $true }
    }

    # ── Authenticate (common to both platforms) ──
    $SmokeCredPassword = ConvertTo-SecureString -String $SepmPass -AsPlainText -Force
    $SmokeCredential   = New-Object System.Management.Automation.PSCredential -ArgumentList $SepmUser, $SmokeCredPassword
    Set-SEPMAuthentication -Credential $SmokeCredential -ErrorAction SilentlyContinue

    # Set-SEPMAuthentication replaces the credential but not an in-memory token, which would
    # otherwise outlive a rotation for the rest of this process.
    & $SmokeModule { $script:accessToken = $null }

    try {
        Get-SEPMAccessToken | Out-Null
    } catch {
        throw "SEPM authentication failed for '$SepmUser' against https://${SepmHost}:${SepmPort}: $($_.Exception.Message) Set SEPM_USER / SEPM_PASS (and SEPM_HOST / SEPM_PORT) to credentials that work for this VM."
    }
}
