# SEPM Smoke Testing

## Environment

| What | Value |
|------|-------|
| VM container | `omarchy-windows` (dockur/windows) |
| SEPM API | `https://172.20.0.2:8446/sepm/api/v{1,2}` from the devcontainer; `https://localhost:8446/sepm/api/v{1,2}` inside the VM. `localhost` does **not** work from the host — only 3389/8006 are published, and the container DNATs the rest to the VM. |
| SEPM version | 14.3.25029.9000 |
| Credentials | SEPM API: `sepm_api` / `Aurelien1!` / domain: `""` — `admin` / `MyComplexPassword1!` is what `Bootstrap.ps1` and `init-sepm-vm.ps1` assume, and this VM rejects it. WinRM: `douda` / `aurelien` |
| WinRM (PS 5.1) | NTLM transport, port 5985, host `172.20.0.2` from the devcontainer (SSL/5986 is broken with pywinrm) |
| Shared volume | `/home/douda/Windows/` ↔ `C:\Users\douda\Desktop\Shared\` (a symlink to `\\host.lan\Data`) |
| VM prerequisites | The module carries `#Requires -Modules ImportExcel`; install it on the VM once with `Install-Module ImportExcel -Scope CurrentUser` or the module cannot be imported at all |

## Connectivity

```bash
docker ps --filter name=omarchy-windows          # VM running?
docker start omarchy-windows                      # start if stopped
curl -sk https://172.20.0.2:8446/sepm/api/v1/version
# → {"API_SEQUENCE":"240604011","API_VERSION":"14.3.9000","version":"14.3.25029.9000"}
```

From the devcontainer, always use `172.20.0.2`; `https://localhost:8446` fails there. The VM's
own `localhost:8446` is only correct for scripts running *inside* the VM.

## Auth

### Credentials and rotation

SEPM credentials are never hardcoded per call site. Every entry point resolves them the same
way: environment variable first, then a default that works against the local dev VM.

| Variable | Default | Notes |
|---|---|---|
| `SEPM_USER` | `sepm_api` | |
| `SEPM_PASS` | `Aurelien1!` | Cleartext is fine — throwaway VMs, rotated credentials |
| `SEPM_HOST` | `172.20.0.2` on PS 7, `localhost` on PS 5.1 | The container reaches the VM at its bridge address; a process on the VM uses loopback |
| `SEPM_PORT` | `8446` | |
| `WINRM_HOST` | `localhost` (`172.20.0.2` from the devcontainer) | |
| `WINRM_PORT` | `5985` | 5986/SSL is broken with pywinrm |
| `WINRM_USER` / `WINRM_PASS` | `douda` / `aurelien` | The VM's Windows account |

Consumers: `Scripts/Smoke/Bootstrap.ps1` (all 39 suites, both platforms),
`Scripts/Smoke/Transport/verify-transport-errors.ps1`, `Scripts/init-sepm-vm.ps1`, and
`Scripts/bootstrap-smoke.sh` (which passes `SEPM_USER`/`SEPM_PASS` down as `SEPM_*`).

`Scripts/invoke-winrm.py` forwards `SEPM_USER` and `SEPM_PASS` into the remote PowerShell
process, so rotating them once covers the PS 5.1 suites too. The SEPM **address** is
deliberately not forwarded — the two sides reach SEPM at different addresses.

Bad credentials stop the run at bootstrap, with the address, the user, the server's own message
and the variables to set — rather than leaving all 39 suites to fail one by one. (Note the
credential file is still written before it is verified; verifying before persisting is a
deferred item in ADR-0010's PR.)

### curl
```bash
TOKEN=$(curl -sk -X POST https://172.20.0.2:8446/sepm/api/v1/identity/authenticate \
  -H "Content-Type: application/json" \
  -d '{"username":"sepm_api","password":"Aurelien1!","appName":"test","domain":""}' \
  | pwsh -NoProfile -c '$i=$input|Out-String;($i|ConvertFrom-Json).token')
# Use: -H "Authorization: Bearer $TOKEN"
```

### PowerShell (module)
```powershell
Set-SepmConfiguration -ServerAddress localhost -Port 8446
Set-SEPMAuthentication
# Or skip the credential prompt — module reads ~/.config/PSSymantecSEPM/creds.xml
```

## Module build & import

```bash
# Build
pwsh -NoProfile -c '
  Import-Module ModuleBuilder -Force
  Build-Module -SourcePath ./Source/PSSymantecSEPM.psd1 -SemVer 0.0.1
'
```

### Smoke test structure (four-file pattern)

Each smoke suite uses three files under `Scripts/Smoke/<Suite>/`, plus one shared bootstrap file:

| File | Purpose |
|------|---------|
| `Scripts/Smoke/Bootstrap.ps1` | Shared across all suites — `Initialize-SmokeBootstrap` handles module import, cert bypass, SEPM config, stale cred cleanup, and authentication. Branches on `$PSVersionTable.PSVersion.Major` internally. |
| `run.ps7.ps1` | PS7 entry point — sets `$RepoRoot`, dot-sources `Bootstrap.ps1` + `Common.ps1` + `Tests.ps1`, calls `Initialize-SmokeBootstrap` |
| `run.ps51.ps1` | PS5.1 entry point — same pattern, hardcoded Windows `$RepoRoot`, UTF-8 BOM |
| `Tests.ps1` | Shared test logic — dot-sourced by both entry points after `Common.ps1` |

Entry points are thin adapters (~6 lines of code). They set `$RepoRoot`, dot-source
`Bootstrap.ps1` and `Common.ps1`, call `Initialize-SmokeBootstrap -RepoRoot $RepoRoot`,
then dot-source the suite's `Tests.ps1`.

`Common.ps1` is a pure helper library — `T`, `Skip`, `Write-Summary` only. No side
effects, no `$PSVersionTable` branching, no config paths, no module import.
Credentials are resolved by `Initialize-SmokeBootstrap` from `SEPM_USER` / `SEPM_PASS` (see
Credentials and rotation), defaulting to `sepm_api` / `Aurelien1!` — not embedded per suite.

See `Scripts/Smoke/README.md` for suite conversion status.

### Manual (bypassing Bootstrap.ps1 + Common.ps1)

Only needed when debugging the smoke infrastructure itself:

```powershell
Import-Module ./Output/PSSymantecSEPM/PSSymantecSEPM.psm1 -Force
$mod = Get-Module PSSymantecSEPM; & $mod { $script:SkipCert = $true }
```

**`$script:SkipCert` must be set in module scope** — `Test-SEPMCertificate.ps1` was deleted by ADR-0001, so nothing auto-detects a self-signed cert.

## Transport error contract — `Scripts/Smoke/Transport/verify-transport-errors.ps1`

Standalone suite, **not** the four-file pattern: it is one self-contained script so it can be
dropped on the VM without the rest of `Scripts/Smoke`. It asserts the ErrorId, ErrorCategory
and message of every way a REST call can fail, against a real SEPM.

Run it before merging any change to `Invoke-SepmApi`, `ConvertTo-SEPMTransportError`,
`Get-SEPMAccessToken` or `Invoke-SepmApiPaginated`.

**Why it exists**: `Tests/Invoke-SepmApi.Tests.ps1` mocks `$PSVersionTable` and
`Invoke-RestMethod`, so the PS 5.1 `HttpWebRequest` branch never executes under Pester and CI
is green either way. A live run is what found the `GetRequestStream` defect — a TLS failure
that escaped the transport as a `MethodInvocationException`, so every POST (authentication
included) reported `SEPM.AuthenticationFailed` instead of `SEPM.CertificateError`. See
`docs/adr/0010-transport-throws-structured-errors.md`.

| Platform | Command |
|---|---|
| PS 7 (devcontainer) | `pwsh -NoProfile -File Scripts/Smoke/Transport/verify-transport-errors.ps1 -ServerAddress 172.20.0.2` |
| PS 5.1 (VM, over WinRM) | deploy first, then `WINRM_HOST=172.20.0.2 WINRM_USER=douda WINRM_PASS=aurelien python3 Scripts/invoke-winrm.py 'C:\Users\douda\Desktop\Shared\verify-transport-errors.ps1'` |

Deploy for the PS 5.1 run (build the module first):

```bash
cp Scripts/Smoke/Transport/verify-transport-errors.ps1 /home/douda/Windows/
rm -rf /home/douda/Windows/PSSymantecSEPM && cp -r ./Output/PSSymantecSEPM /home/douda/Windows/PSSymantecSEPM
```

It imports the built module, points it at SEPM, and snapshots/restores the module's
config / credential / token files around the run. Both platforms print the same
`TOTAL: N tests, N pass, N fail, N skip` line as the smoke suites, exit non-zero on failure,
and accept `-ReportPath` to write the full log somewhere readable from the host.

Two things that will otherwise waste an hour:

- **Check 1 (untrusted certificate) must run before anything sets `$script:SkipCert = $true`.**
  `Skip-Cert` installs a process-wide `ServicePointManager.ServerCertificateValidationCallback`
  that cannot be unset, so the check is only meaningful in a fresh process. Do not reorder it,
  and do not run it in the same process as `Initialize-SmokeBootstrap`, which authenticates and
  installs the callback.
- **The VM caches the shared folder over SMB.** After redeploying a file, the VM can still run
  the previous copy, and reading a file the host replaced in place can fail with *"The parameter
  is incorrect"* until the share is revalidated. Delete the target from the VM side, or read a
  different file in the same folder, to force a fresh read.

## Test policy

Only one exception policy exists:

| Name | ID | Type |
|------|----|------|
| `Exceptions policy` | `4C4BC60CAC1E00027A25369C305828F9` | exceptions |

### Verify state (Invoke-SepmApi — works on both PS7 and PS5.1)

```powershell
$s = Initialize-SEPMSession
$p = Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv2)/policies/exceptions/4C4BC60CAC1E00027A25369C305828F9" `
    -Headers $s.Headers -SkipCert:$true
$p.enabled; $p.desc; $p.configuration.files
```

Invoke-SepmApi uses Invoke-RestMethod on PS7 and HttpWebRequest+KeepAlive=false on PS5.1 (see Source/Private/Invoke-SepmApi.ps1 for rationale).

### Verify state (curl)

```bash
curl -sk https://172.20.0.2:8446/sepm/api/v2/policies/exceptions/4C4BC60CAC1E00027A25369C305828F9 \
  -H "Authorization: Bearer $TOKEN" | python3 -c "
import json,sys; d=json.load(sys.stdin)
print(f'enabled={d.get(\"enabled\")} desc={d.get(\"desc\")} files={len(d.get(\"configuration\",{}).get(\"files\",[]))}')"
```

### Ground truth: curl PATCH (add/remove file exception)

```bash
# ADD
curl -sk -X PATCH https://172.20.0.2:8446/sepm/api/v2/policies/exceptions/4C4BC60CAC1E00027A25369C305828F9 \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"configuration":{"files":[{"pathvariable":"[NONE]","scancategory":"AllScans","rulestate":{"source":"PSSymantecSEPM","enabled":true},"path":"C:\\Temp\\TestSmoke.exe","deleted":false,"securityrisk":true,"applicationcontrol":true,"sonar":true}]},"name":"Exceptions policy"}'

# REMOVE (deleted:true)
...same body with "deleted":true...
```

### Ground truth: curl PATCH (metadata only — enable/disable/desc)

```bash
# Disable
curl -sk -X PATCH .../4C4BC60CAC1E00027A25369C305828F9 -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"enabled":false,"name":"Exceptions policy"}'

# Set description
curl -sk -X PATCH ... -d '{"enabled":true,"desc":"My description","name":"Exceptions policy"}'
```

## Invoke-WebRequest for isolation tests

When debugging PATCH issues, bypass `Invoke-ABRestMethod`:

```powershell
$s = Initialize-SEPMSession
$body = @{name="Exceptions policy";enabled=$false;desc="Test"} | ConvertTo-Json -Compress
$r = Invoke-WebRequest -Method PATCH -Uri "$($s.BaseURLv2)/policies/exceptions/4C4BC60CAC1E00027A25369C305828F9" `
  -Body $body -Headers $s.Headers -SkipCertificateCheck -ContentType "application/json"
$r.StatusCode  # 200 = success
```

## PS 5.1 (WinRM)

### Automated (bootstrap-smoke.sh)

`Scripts/bootstrap-smoke.sh` handles deployment and execution automatically:

```bash
bash Scripts/bootstrap-smoke.sh
```

It deploys the module + `Scripts/Smoke/` tree to the shared volume, then discovers
and runs all `*/run.ps51.ps1` suites via WinRM. See `Scripts/Smoke/README.md` for
suite status.

### Manual (single suite)

```bash
# Deploy module + smoke scripts to shared volume
cp -r ./Output/PSSymantecSEPM /home/douda/Windows/PSSymantecSEPM
cp -r ./Scripts/Smoke /home/douda/Windows/Scripts/Smoke

# Run via WinRM (NTLM transport, port 5985; 172.20.0.2 from the devcontainer)
WINRM_HOST=172.20.0.2 WINRM_PORT=5985 WINRM_USER=douda WINRM_PASS=aurelien \
    python3 Scripts/invoke-winrm.py 'C:\Users\douda\Desktop\Shared\Scripts\Smoke\<Suite>\run.ps51.ps1'
```

`invoke-winrm.py` handles NTLM auth on port 5985 and forwards `SEPM_USER` / `SEPM_PASS` to the
VM. SSL/5986 is broken with pywinrm. Its defaults (`douda` / `aurelien`, `localhost`) fit this
VM; override with `WINRM_*` when they do not, and use `WINRM_HOST=172.20.0.2` from the
devcontainer.

**Transport**: PS5.1 uses `[HttpWebRequest]` with `KeepAlive=false` (via `Invoke-SepmApi`, see Source/Private/Invoke-SepmApi.ps1).
`Invoke-RestMethod` on .NET Framework 4.x reuses TLS connections which SEPM 14.3 rejects.

`invoke-winrm.py` runs the script through `-EncodedCommand`, so the VM serializes its
information and error streams to stderr as `#< CLIXML` blobs. That is noise, not a failure —
stdout and the `TOTAL:` line stay clean, and `bootstrap-smoke.sh` parses those.

**PS 5.1 differences**: no `-SkipCertificateCheck` (use `ServicePointManager` callback); all .ps1 files need UTF-8 BOM; `ConvertFrom-Json` lacks `-AsHashtable`/`-Depth`.

## Smoke scripts

Smoke scripts are organized by cmdlet under `Scripts/Smoke/<CmdletName>/`.
Each suite uses the three-file entry point pattern (`run.ps7.ps1`, `run.ps51.ps1`, `Tests.ps1`).

All entry points dot-source `Scripts/Smoke/Bootstrap.ps1` (platform-specific module import,
cert bypass, config, auth via `Initialize-SmokeBootstrap`), then `Scripts/Smoke/Common.ps1`
(pure helpers: `T`, `Skip`, `Write-Summary`), then their suite's `Tests.ps1` (shared test
logic). Only the entry point preamble differs between PS7 and PS5.1.

See `Scripts/Smoke/README.md` for which suites are converted and which still need migration.

```bash
# PS7 (single suite)
pwsh -NoProfile -File Scripts/Smoke/<Suite>/run.ps7.ps1

# PS5.1 (single suite — manual deploy first)
cp -r ./Output/PSSymantecSEPM /home/douda/Windows/PSSymantecSEPM
cp -r ./Scripts/Smoke /home/douda/Windows/Scripts/Smoke
WINRM_HOST=172.20.0.2 WINRM_USER=douda WINRM_PASS=aurelien \
    python3 Scripts/invoke-winrm.py 'C:\Users\douda\Desktop\Shared\Scripts\Smoke\<Suite>\run.ps51.ps1'

# All suites (both platforms)
bash Scripts/bootstrap-smoke.sh
```

## Known bugs

### 1. `Get-SEPComputers` — infinite loop on error (pre-existing)

`do..until($resp.lastPage)` never terminates when `$resp` is an error string.

### 2. SEPM JSON duplicate keys — `sonar`/`SONAR`

SEPM 14.3 returns JSON with case-insensitive duplicate keys (e.g., `"sonar"` and `"SONAR"` in the same object).
PowerShell's `ConvertFrom-Json` rejects these on both PS versions.
`Invoke-SepmApi` uses `-AsHashtable` (PS7) and `JavaScriptSerializer` (PS5.1) as tolerant parsers.

## File layout

```
~/.config/PSSymantecSEPM/config.json          # {port, ServerAddress}
~/.config/PSSymantecSEPM/creds.xml            # encrypted creds (Export-Clixml)
~/.local/share/PSSymantecSEPM/accessToken.xml # cached token
~/Windows/                                    # shared with Windows VM
Source/Private/00_Exceptions-Policy.ps1       # PowerShell class (loads first)
Source/Private/Invoke-ABRestMethod.ps1        # DEPRECATED — replaced by Invoke-SepmApi
Source/Private/Invoke-SepmApi.ps1             # REST layer (PS7: Invoke-RestMethod, PS5.1: HttpWebRequest)
Source/Private/Initialize-SEPMSession.ps1     # session factory
Output/PSSymantecSEPM/                        # built module
Scripts/Smoke/Bootstrap.ps1                   # shared bootstrap (module import, cert bypass, config, auth)
Scripts/Smoke/Common.ps1                      # pure helper library (T/Skip/Write-Summary)
Scripts/Smoke/<Suite>/run.ps7.ps1             # PS7 entry point per suite
Scripts/Smoke/<Suite>/run.ps51.ps1            # PS5.1 entry point per suite
Scripts/Smoke/<Suite>/Tests.ps1               # shared test logic per suite
Scripts/Smoke/README.md                       # migration status
Scripts/bootstrap-smoke.sh                    # full-suite orchestrator
Scripts/invoke-winrm.py                       # PS 5.1 test runner
```
