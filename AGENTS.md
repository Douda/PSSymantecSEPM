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
│   ├── Invoke-SepmApi.ps1       # Unified REST transport (ADR-0003)
│   ├── Initialize-SEPMSession.ps1
│   ├── Get-SEPMAccessToken.ps1
│   ├── ... (24 files total)
│   └── Skip-Cert.ps1            # PS 5.1 cert bypass via Add-Type C#
├── Public/                      # Exported cmdlets (55 files)
│   ├── Get-SEPComputers.ps1     # Paginated, filterable by name or group
│   ├── Set-SepmAuthentication.ps1
│   ├── Get-SEPMAccessToken.ps1
│   ├── Update-SEPMExceptionPolicy.ps1
│   └── ... (one file per cmdlet)
├── en-US/about_PSSymantecSEPM.help.txt
└── build.psd1                   # ModuleBuilder config
Tests/
├── TestHelpers/                 # Test infrastructure module
│   ├── PSSymantecSEPM.TestHelpers.psd1
│   └── PSSymantecSEPM.TestHelpers.psm1
├── fixtures/                    # JSON response fixtures for seed tests
├── Get-SEPComputers.Tests.ps1
├── Get-SEPMVersion.Tests.ps1
├── Seed-SEPMData.Tests.ps1
└── ... (35+ test files, one per cmdlet/private function)
Scripts/
├── Smoke/                        # Live smoke tests (per cmdlet)
│   └── Update-SEPMExceptionPolicy/
│       ├── batch.ps7.ps1
│       ├── batch.ps51.ps1
│       └── metadata.ps7.ps1
├── Get-SEPKpiOldDefinitions.ps1
├── invoke-winrm.py               # PS 5.1 test runner
└── setup-vm.ps1                  # Fresh VM configuration
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

### REST layer (Invoke-SepmApi)
Single unified transport (ADR-0003). Two parameter sets:
- **`-Session`**: Extracts `Headers` and `SkipCert` from a session object (created by `Initialize-SEPMSession`)
- **`-Headers`/`-SkipCert`**: Manual overrides for auth bootstrap (`Get-SEPMAccessToken`)

Returns `[hashtable]` uniformly across PS versions via `ConvertTo-Hashtable`.
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

### What works
- Authentication against SEPM (token-based)
- Computer inventory (list, filter by name/group, paginate)
- Client status, version, definition versions, infected status
- Groups (list, create, remove)
- Policies (exception, firewall, IPS — read/write)
- Policy exception mutations (add/remove file, folder, extension exceptions)
- Commands (active scan, full scan, quarantine, get file, clear iron cache)
- GUPs, domains, admins, database info, license, replication status, threat stats
- Move clients between groups
- Location management (list, get XML)
- File fingerprint list management
- Configuration backup/restore
- Excel export (firewall policies)

### Output emission: `Write-Output -NoEnumerate` for collections

Cmdlets that return collections (arrays built via `@()`, or API response sub-properties
extracted as arrays) must use `Write-Output $result -NoEnumerate` instead of bare
`return $result`. PowerShell unrolls arrays through `return`, causing a single-element
result to become a scalar — breaking `$result.Count`, pipeline `ForEach-Object`, and
other array-dependent downstream code.

**Applies to**: cmdlets where the return type is conceptually "a list of X."
**Does not apply to**: cmdlets returning a single object (hashtable, PSCustomObject,
boolean, string), even if the object internally contains nested arrays.

Audited 2026-06-09 — 13 cmdlets use this pattern:

| Cmdlet | Returns |
|---|---|
| `Get-SEPComputers` | Paginated computer array |
| `Get-SEPMGroups` | Paginated group array |
| `Get-SEPMCommandStatus` | Paginated command status array |
| `Get-SEPGUPList` | GUP array |
| `Get-SEPMLocation` | Location array |
| `Get-SEPClientDefVersions` | Definition version array |
| `Get-SEPClientStatus` | Client status array |
| `Get-SEPClientVersion` | Client version array |
| `Get-SEPMEventInfo` | Critical events array |
| `Get-SEPMPoliciesSummary` | Policy summary array |
| `Get-SEPMReplicationStatus` | Replication status array |
| `Get-SEPMThreatStats` | Threat stats array |
| `Send-SEPMCommand` | Command result array |

New cmdlets returning collections should follow this pattern.

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
export WINRM_USER=<username>
export WINRM_PASS=<password>
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
Invoke-Pester -Path ./Tests -Output Normal

# Run single test file
Invoke-Pester -Path ./Tests/Get-SEPComputers.Tests.ps1 -Output Normal

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
#   export WINRM_USER=<username> WINRM_PASS=<password>
cp -r ./Output/PSSymantecSEPM /home/douda/Windows/PSSymantecSEPM  # deploy to shared volume
python3 Scripts/invoke-winrm.py 'C:\Users\<username>\Desktop\Shared\test-module.ps1'
```

## Agent Notes

### WinRM (PS 5.1 testing)
- WinRM enabled on Windows VM with HTTP (5985) and HTTPS (5986) listeners.
- HTTPS/SSL listener broken for pywinrm (timeout/ConnectionReset). Use **NTLM transport on port 5985**.
- Python `pywinrm` with `transport='ntlm'` on port 5985 works. Pre-installed in image.
- Credentials: `smokeuser` / `smokepassword`. Set via `WINRM_USER` / `WINRM_PASS` env vars.
- Always pass `-ExecutionPolicy Bypass` — WinRM sessions have Restricted policy.
- Setup script: copy `Scripts/setup-vm.ps1` to shared volume, run as Admin once on new VM.
- Runner: `python3 Scripts/invoke-winrm.py '<path-to-ps1-on-vm>'`

### Encoding
- **ModuleBuilder handles BOM** for the assembled `.psm1` — source files in `Source/` can be UTF-8 without BOM. The assembled module works correctly on both PS versions.
- **Standalone scripts deployed to the Windows VM** must have a UTF-8 BOM prefix (`\xef\xbb\xbf`) if they contain non-ASCII characters (special chars, Unicode). Without it, the PS 5.1 parser mangles them. Smoke scripts (`Scripts/Smoke/<Cmdlet>/batch.ps51.ps1`) are deployed with BOM via `[System.Text.UTF8Encoding]::new(\$true)`.
- PowerShell 7+ (in the devcontainer) handles UTF-8 without BOM fine.

### Path separators
- All `Join-Path -ChildPath` calls must use forward slashes — backslashes break on Linux.
- Already fixed across all test files.

### Certificate handling
- On PS 5.1 (Windows VM): use `[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }` to bypass. `-SkipCertificateCheck` doesn't exist.
- On PS 7+ (devcontainer): use `-SkipCertificateCheck`.
- The module's `Test-SEPMCertificate.ps1` is currently a no-op (everything commented out).

### Build system
- `ModuleBuilder` assembles split source into a single `.psm1`. Always rebuild after adding new source files.
- The `zz_` prefix convention ensures init runs last.
- `RequiredModules.psd1` at repo root lists build/test dependencies (`ModuleBuilder`, `Configuration`, `Pester 5.*`, `PSScriptAnalyzer`).

### Test architecture
- **TestHelpers module** (`Tests/TestHelpers/`) provides `Initialize-TestEnvironment` (builds+imports module, redirects file paths to `TestDrive:`, resets module state) and `Clear-TestEnvironment` (removes module, cleans up). Also exports `New-TestSession` for creating mock session objects.
- **Seam layers** for mocking (see `boundary-mocking.md`):
  - **Auth seam**: Mock `Initialize-SEPMSession` — returns a `New-TestSession` object. All cmdlets call this for auth.
  - **Transport seam**: Mock `Invoke-SepmApi` — returns a `[hashtable]` fixture. All cmdlets call this for HTTP.
  - **File seam**: Paths redirected to `TestDrive:` by `Initialize-TestEnvironment`. No direct filesystem access in tests.
  - **HTTP seam**: Not tested at unit level — smoke tests cover the live API.
- **InModuleScope** is reserved for transport/auth/tooling layer tests only: `Invoke-SepmApi`, `Initialize-SEPMSession`, and TestHelpers lifecycle functions.
- **PS version strategy**: Unit tests mock `$PSVersionTable.PSVersion.Major` where needed to exercise PS 5.1 vs 7+ code paths. Transport tests (`Invoke-SepmApi`) test both branches. Most cmdlet tests don't branch on PS version — the transport layer abstracts it away.
- **Seed tests** (`Seed-*.Tests.ps1`) validate that `Seed-SEPMData` correctly populates the SEPM VM with test data. They hit the live API.

## Agent skills

### Issue tracker

GitHub Issues, using the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

All five canonical labels use their defaults (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context — one `CONTEXT.md` at the repo root, one `docs/adr/` directory. See `docs/agents/domain.md`.

### Live smoke testing

How to interact with the local SEPM VM for live API smoke tests (auth, curl, PS 7, PS 5.1). See `docs/agents/smoke-testing.md`.

Credentials: SEPM: `admin` / `MyComplexPassword1!`; WinRM: `smokeuser` / `smokepassword`; SEPM backup: `douda` / `Aurelien1!` (VM in docker-compose, local dev only).
