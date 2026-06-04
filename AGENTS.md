# PSSymantecSEPM — Agent Context

PowerShell module wrapping the Symantec Endpoint Protection Manager (SEPM) REST API.
Target environment: SEPM 14.3 (Windows VM running via dockur/windows in Docker).

## Repo Structure

```
Source/
├── PSSymantecSEPM.psd1          # Module manifest
├── PSSymantecSEPM.Types.ps1xml  # Extended type data (epoch→DateTime, ScriptMethod)
├── Classes/
│   └── Exceptions-Policy.ps1    # PowerShell class for policy exception payloads
├── Private/                     # Internal helpers (not exported)
│   ├── Build-SEPMQueryURI.ps1
│   ├── Import-SepmConfiguration.ps1
│   ├── Initialize-PolicyExceptionStructure.ps1
│   ├── Invoke-ABRestMethod.ps1
│   ├── Optimize-ExceptionPolicyStructure.ps1
│   ├── Read-SepmConfiguration.ps1
│   ├── Remove-NestedNullOrEmptyProperties.ps1
│   ├── Resolve-PropertyValue.ps1
│   ├── Save-SepmConfiguration.ps1
│   ├── Skip-Cert.ps1            # PS 5.1 cert bypass via Add-Type C#
│   ├── Test-PropertyExists.ps1
│   ├── Test-SEPMAccessToken.ps1
│   └── Test-SEPMCertificate.ps1
├── Public/                      # Exported cmdlets (~45 files)
│   ├── Get-SEPComputers.ps1     # Paginated, filterable by name or group
│   ├── Set-SepmAuthentication.ps1
│   ├── Get-SEPMAccessToken.ps1
│   ├── Add-SEPMWindowsFileException.ps1
│   ├── Get-SEPMExceptionPolicy.ps1
│   └── ... (one file per cmdlet)
├── To_Update/                   # Unfinished cmdlets (Get-SEPFileContent, Get-TDADPolicy, Update-SEPMExceptionPolicy)
├── en-US/about_PSSymantecSEPM.help.txt
└── build.psd1                   # ModuleBuilder config
Tests/
├── Config/                      # Pester bootstrap (init, before/after all, test env setup)
├── Build-SEPMQueryURI.Tests.ps1
├── Get-SEPComputers.Tests.ps1
├── Get-SEPMAccessToken.Tests.ps1
├── Set-SEPMAuthentication.Tests.ps1
├── ... (one test file per module function)
└── DummyDataGenerator.ps1       # Test fixtures for SEPM API responses
Scripts/
├── Get-SEPKpiOldDefinitions.ps1
└── WIP_SEPM_KPIs.ps1
.vscode/                         # Shared workspace configs
├── settings.json
├── launch.json
└── tasks.json
.devcontainer/                   # Dev container config
└── devcontainer.json
```

## Architecture

### Auth flow (Get-SEPMAccessToken)
```
1. Check parameter token → 2. Check $script:accessToken → 3. Check disk cache (Export-Clixml)
→ 4. Check credentials in $script:Credential or disk → 5. POST /identity/authenticate → cache result
```

Tokens expire after a time window (returned by API). `Test-SEPMAccessToken` validates expiry before use.

### REST layer (Invoke-ABRestMethod)
Branches on `$PSVersionTable.PSVersion.Major`:
- **PS 6+**: Uses `Invoke-RestMethod -SkipCertificateCheck`
- **PS 5.1**: Uses `Skip-Cert` C# callback via `Add-Type`

### Configuration persistence
- `~/.config/PSSymantecSEPM/config.json` — server address, port, domain (JSON)
- `~/.config/PSSymantecSEPM/creds.xml` — encrypted credentials (Export-Clixml)
- `~/.local/share/PSSymantecSEPM/accessToken.xml` — cached token (Export-Clixml)

### Module build (ModuleBuilder)
Source is split into individual `.ps1` files. `ModuleBuilder` assembles them into a single `.psm1` in `Output/`. The `zz_` prefix on `zz_Initialize-SepmConfiguration.ps1` ensures it loads last.

### Pagination
Some cmdlets (e.g. `Get-SEPComputers`) paginate through the API using `pageIndex`/`pageSize` query params, looping until `lastPage == true`.

## Current State

### Known issues
- **Test-SEPMCertificate.ps1** — entirely commented out (commit `e1f2178`). Self-signed certs are never detected automatically. The `-SkipCertificateCheck` parameter on each cmdlet works, but there's no automatic fallback.
- **No Update-SEPMExceptionPolicy** — the `To_Update/` folder has a skeleton but it's not wired into the module. Exception policies can be read (Get) but not written (Update).
- **Several policy types have no cmdlets**: AV, ADC, HI, HID, LU, LUCONTENT, MEM, MSL, NTR, UPGRADE — only `Get` exists for `exceptions`, `fw`, `ips`.
- **Tests reference PS 4.7.2–5.0** — `RequiredModules.psd1` now targets `5.*` but tests haven't been migrated.

### What works
- Authentication against SEPM (token-based)
- Computer inventory (list, filter by name/group, paginate)
- Client status, version, definition versions, infected status
- Groups (list, create, remove)
- Policies (exception, firewall, IPS — read only)
- Policy exception mutations (add/remove file, folder, extension exceptions)
- Commands (active scan, full scan, quarantine, get file, clear iron cache)
- GUPs, domains, admins, database info, license, replication status, threat stats
- Move clients between groups
- Location management (list, get XML)
- File fingerprint list management

## Dev Environment

```
Linux Host (Omarchy/Arch)        Docker container: omarchy-windows
└─ VS Code                       └─ dockur/windows
   └─ Dev container                 └─ QEMU/KVM
      └─ pwsh + ModuleBuilder          └─ Windows 11 + SEPM 14.3
```

- VM accessible at `https://127.0.0.1:8446/sepm/api/v1/` (SEPM REST API)
- Also `https://127.0.0.1:9090` (SEPM Console)
- Shared volume: `/home/douda/Windows/` ↔ `C:\Shared\` in VM
- Docker compose: `~/.config/windows/docker-compose.yml`

## Fresh VM Setup

When setting up a new Windows VM for development, run one script once.

### On the host (before starting devcontainer)

```bash
export WINRM_USER=douda
export WINRM_PASS=aurelien
```

### In the Windows VM (run as Administrator once)

Copy `Scripts/setup-vm.ps1` to the shared volume, then:
```powershell
C:\Users\<user>\Desktop\Shared\setup-vm.ps1 -RemoteUser <username>
```

This single script does:
- Enables WinRM, sets it to auto-start
- Configures Basic auth, firewall rules (5985/5986)
- Adds the user to Remote Management Users + Administrators
- Creates a self-signed SSL cert with Server Authentication EKU
- Creates an HTTPS WinRM listener on port 5986
- Restarts WinRM and prints verification status

No other manual steps needed. After this, the VM is reachable from the devcontainer
via `python3 Scripts/invoke-winrm.py`.

## Local Commands

```powershell
# Build module from source
Build-Module -SourcePath ./Source/PSSymantecSEPM.psd1 -SemVer 0.0.1

# Import built module
Import-Module ./Output/PSSymantecSEPM/PSSymantecSEPM.psm1 -Force

# Agent helper (defined in container's pwsh profile)
Build-ModuleLocal

# Run tests
Invoke-Pester ./Tests -Output Detailed

# Run single test file
Invoke-Pester ./Tests/Build-SEPMQueryURI.Tests.ps1 -Output Detailed

# Configure & auth against local VM
Set-SepmConfiguration -ServerAddress "host.docker.internal" -Port 8446
Set-SEPMAuthentication

# SkipCert must be set INSIDE module scope (Test-SEPMCertificate is disabled)
$mod = Get-Module PSSymantecSEPM; & $mod { $script:SkipCert = $true }

Get-SEPMAccessToken

# Quick smoke test
Get-SEPMVersion
Get-SEPComputers

# PS 5.1 testing (via WinRM SSL transport)
# Set env vars on your host before opening the devcontainer:
#   export WINRM_USER=douda WINRM_PASS=aurelien
cp -r ./Output/PSSymantecSEPM /home/douda/Windows/PSSymantecSEPM  # deploy to shared volume
python3 Scripts/invoke-winrm.py 'C:\Users\douda\Desktop\Shared\test-module.ps1'
```

## Agent Notes

### WinRM (PS 5.1 testing)
- WinRM enabled on Windows VM with HTTP (5985) and HTTPS (5986) listeners.
- HTTPS listener broken for pywinrm/PSWSMan (ConnectionReset) — use **SSL transport**.
- Python `pywinrm` with `transport='ssl'` on port 5986 works. Pre-installed in image.
- Credentials via `WINRM_USER` / `WINRM_PASS` env vars (set on host before opening devcontainer).
- Always pass `-ExecutionPolicy Bypass` — WinRM sessions have Restricted policy.
- Setup script: copy `Scripts/setup-vm.ps1` to shared volume, run as Admin once on new VM.
- Runner: `python3 Scripts/invoke-winrm.py '<path-to-ps1-on-vm>'`

### Encoding
- **Windows PowerShell 5.1 requires UTF-8 with BOM.** Files written to the shared volume (`/home/douda/Windows/`) that are meant to run on the Windows VM must have a UTF-8 BOM prefix (`\xef\xbb\xbf`). Without it, Unicode characters get mangled and the parser breaks on special characters.
- PowerShell 7+ (in the devcontainer) handles UTF-8 without BOM fine.

### Path separators
- All `Join-Path -ChildPath` calls must use forward slashes (`Tests/Config/Common-Init.ps1`) — backslashes break on Linux.
- Already fixed across all test files.

### Certificate handling
- On PS 5.1 (Windows VM): use `[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }` to bypass. `-SkipCertificateCheck` doesn't exist.
- On PS 7+ (devcontainer): use `-SkipCertificateCheck`.
- The module's `Test-SEPMCertificate.ps1` is currently a no-op (everything commented out).

### Build system
- `ModuleBuilder` assembles split source into a single `.psm1`. Always rebuild after adding new source files.
- The `zz_` prefix convention ensures init runs last.
- `RequiredModules.psd1` lists build/test dependencies.
