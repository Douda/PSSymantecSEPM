# SEPM Smoke Testing

## Environment

| What | Value |
|------|-------|
| VM container | `omarchy-windows` (dockur/windows) |
| SEPM API | `https://localhost:8446/sepm/api/v{1,2}` |
| SEPM version | 14.3.25029.9000 |
| Credentials | SEPM: `admin` / `MyComplexPassword1!` / domain: `""`; WinRM: `smokeuser` / `smokepassword` |
| WinRM (PS 5.1) | NTLM transport, port 5985, `localhost` (SSL/5986 broken with pywinrm) |
| Shared volume | `/home/douda/Windows/` ↔ `C:\Users\smokeuser\Desktop\Shared\` |

## Connectivity

```bash
docker ps --filter name=omarchy-windows          # VM running?
docker start omarchy-windows                      # start if stopped
curl -sk https://localhost:8446/sepm/api/v1/version
# → {"API_SEQUENCE":"240604011","API_VERSION":"14.3.9000","version":"14.3.25029.9000"}
```

## Auth

### curl
```bash
TOKEN=$(curl -sk -X POST https://localhost:8446/sepm/api/v1/identity/authenticate \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"MyComplexPassword1!","appName":"test","domain":""}' \
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

### Quick smoke (one-liner after Common.ps1)

All smoke scripts dot-source `Scripts/Smoke/Common.ps1` which handles module import,
certificate bypass (`$script:SkipCert`), SEPM configuration, and authentication in one line:

```powershell
$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"
```

Common.ps1 also exports `T` and `Skip` helper functions used by all smoke scripts.
Credentials (`admin` / `MyComplexPassword1!`) live in Common.ps1 and Common-PS51.ps1 —
change them once, all smoke scripts update.

### Manual (bypassing Common.ps1)

Only needed when debugging the smoke infrastructure itself:

```powershell
Import-Module ./Output/PSSymantecSEPM/PSSymantecSEPM.psm1 -Force
$mod = Get-Module PSSymantecSEPM; & $mod { $script:SkipCert = $true }
```

**`$script:SkipCert` must be set in module scope** — `Test-SEPMCertificate` is disabled (no auto-detect of self-signed certs).

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
curl -sk https://localhost:8446/sepm/api/v2/policies/exceptions/4C4BC60CAC1E00027A25369C305828F9 \
  -H "Authorization: Bearer $TOKEN" | python3 -c "
import json,sys; d=json.load(sys.stdin)
print(f'enabled={d.get(\"enabled\")} desc={d.get(\"desc\")} files={len(d.get(\"configuration\",{}).get(\"files\",[]))}')"
```

### Ground truth: curl PATCH (add/remove file exception)

```bash
# ADD
curl -sk -X PATCH https://localhost:8446/sepm/api/v2/policies/exceptions/4C4BC60CAC1E00027A25369C305828F9 \
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

```bash
# Deploy module
cp -r ./Output/PSSymantecSEPM /home/douda/Windows/PSSymantecSEPM

# Deploy shared init (once per VM session)
pwsh -NoProfile -c "
  \$bom = [System.Text.UTF8Encoding]::new(\$true)
  \$c = Get-Content ./Scripts/Smoke/Common-PS51.ps1 -Raw
  [System.IO.File]::WriteAllText('/home/douda/Windows/Common-PS51.ps1', \$c, \$bom)
"
```

All PS5.1 smoke scripts dot-source Common-PS51.ps1:
```powershell
$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"
. "$RepoRoot\Common-PS51.ps1"
```

This handles TLS 1.2, certificate bypass, module import, SEPM config, and
authentication. Write the script body with just assertions.

### Writing a PS5.1 smoke script (UTF-8 BOM mandatory)

```bash
printf '\xef\xbb\xbf' > /home/douda/Windows/smoke-<cmdlet>.ps1
cat >> /home/douda/Windows/smoke-<cmdlet>.ps1 << 'EOF'
$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"
. "$RepoRoot\Common-PS51.ps1"

# ... smoke assertions ...
EOF
```

### Run (NTLM transport, port 5985)

```bash
python3 Scripts/invoke-winrm.py 'C:\Users\smokeuser\Desktop\Shared\smoke-<cmdlet>.ps1'
```

`invoke-winrm.py` handles NTLM auth on port 5985. SSL/5986 is broken with pywinrm.

**Transport**: PS5.1 uses `[HttpWebRequest]` with `KeepAlive=false` (via `Invoke-SepmApi`, see Source/Private/Invoke-SepmApi.ps1).
`Invoke-RestMethod` on .NET Framework 4.x reuses TLS connections which SEPM 14.3 rejects.

**PS 5.1 differences**: no `-SkipCertificateCheck` (use callback above); all .ps1 files need UTF-8 BOM; `ConvertFrom-Json` lacks `-AsHashtable`/`-Depth`.

## Smoke scripts

Smoke scripts are organized by cmdlet under `Scripts/Smoke/<CmdletName>/`.
Each cmdlet directory has `batch.ps7.ps1`, `batch.ps51.ps1`, and optional helpers.

All scripts dot-source a shared init file that handles module import, auth,
and provides `T`/`Skip` helper functions:
- PS7: `Scripts/Smoke/Common.ps1`
- PS5.1: `Scripts/Smoke/Common-PS51.ps1` (deployed to shared volume)

| Suite | Purpose |
|-------|---------|
| `Seed-SEPMData` | Orchestrator skeleton: Test category + Force flag |
| `Get-SEPMFiles` | File fingerprint list + file details GET |
| `Get-SEPMInfrastructure` | GUP list, license, database info, latest definitions |
| `Get-SEPMLocations` | Location list + XML export |
| `Update-SEPMExceptionPolicy` | Full PATCH matrix (35 tests per runtime) |

Only the preamble differs between PS7 and PS5.1 — the test logic is identical.

```bash
# PS7
pwsh -NoProfile -File Scripts/Smoke/<Suite>/batch.ps7.ps1

# PS5.1
cp -r ./Output/PSSymantecSEPM /home/douda/Windows/PSSymantecSEPM
pwsh -NoProfile -c "
  \$bom = [System.Text.UTF8Encoding]::new(\$true)
  \$c = Get-Content ./Scripts/Smoke/<Suite>/batch.ps51.ps1 -Raw
  [System.IO.File]::WriteAllText('/home/douda/Windows/smoke-<suite>.ps1', \$c, \$bom)
"
python3 Scripts/invoke-winrm.py 'C:\Users\smokeuser\Desktop\Shared\smoke-<suite>.ps1'
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
~/.config/PSSymantecSEPM/config.json         # {port, ServerAddress}
~/.config/PSSymantecSEPM/creds.xml           # encrypted creds (Export-Clixml)
~/.local/share/PSSymantecSEPM/accessToken.xml # cached token
~/Windows/                                   # shared with Windows VM
Source/Private/00_Exceptions-Policy.ps1      # PowerShell class (loads first)
Source/Private/Invoke-ABRestMethod.ps1       # DEPRECATED — being replaced by Invoke-SepmApi
Source/Private/Invoke-SepmApi.ps1            # New REST layer (PS7: Invoke-RestMethod, PS5.1: HttpWebRequest)
Source/Private/Initialize-SEPMSession.ps1    # session factory
Output/PSSymantecSEPM/                       # built module
Scripts/invoke-winrm.py                      # PS 5.1 test runner
```
