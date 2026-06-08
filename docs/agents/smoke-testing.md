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

# Import + configure + auth
pwsh -NoProfile -c '
  @{port=8446;ServerAddress="localhost"}|ConvertTo-Json |
    Set-Content "$env:HOME/.config/PSSymantecSEPM/config.json" -Force
  rm "$env:HOME/.local/share/PSSymantecSEPM/accessToken.xml" -Force -EA SilentlyContinue
  Import-Module ./Output/PSSymantecSEPM/PSSymantecSEPM.psm1 -Force
  $mod=Get-Module PSSymantecSEPM; & $mod {$script:SkipCert=$true}
  Get-SEPMVersion; Get-SEPMAccessToken
'
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

# Write test script with UTF-8 BOM (mandatory for PS 5.1)
printf '\xef\xbb\xbf' > /home/douda/Windows/test-ps51.ps1
cat >> /home/douda/Windows/test-ps51.ps1 << 'EOF'
$ErrorActionPreference="Continue"
[System.Net.ServicePointManager]::ServerCertificateValidationCallback={$true}
[System.Net.ServicePointManager]::SecurityProtocol=[System.Net.SecurityProtocolType]::Tls12
$cfg="$env:APPDATA\PSSymantecSEPM\config.json"
New-Item -ItemType Directory (Split-Path $cfg) -Force|Out-Null
@{port=8446;ServerAddress="localhost"}|ConvertTo-Json|Set-Content $cfg -Force
Import-Module C:\Users\smokeuser\Desktop\Shared\PSSymantecSEPM\PSSymantecSEPM.psm1 -Force
$mod=Get-Module PSSymantecSEPM; & $mod {$script:SkipCert=$true}
Get-SEPMVersion
# ... test commands ...
EOF

# Run (NTLM transport, port 5985 — invoke-winrm.py defaults to broken SSL/5986)
python3 -c "
import winrm
s = winrm.Session('localhost:5985', auth=('smokeuser','smokepassword'), transport='ntlm')
r = s.run_cmd('powershell -ExecutionPolicy Bypass -File \"C:\\\\Users\\\\smokeuser\\\\Desktop\\\\Shared\\\\test-ps51.ps1\"')
print(r.std_out.decode())
"
```

**Transport**: PS5.1 uses `[HttpWebRequest]` with `KeepAlive=false` (via `Invoke-SepmApi`, see Source/Private/Invoke-SepmApi.ps1).
`Invoke-RestMethod` on .NET Framework 4.x reuses TLS connections which SEPM 14.3 rejects.

**PS 5.1 differences**: no `-SkipCertificateCheck` (use callback above); all .ps1 files need UTF-8 BOM; `ConvertFrom-Json` lacks `-AsHashtable`/`-Depth`.

## Smoke scripts

| Script | Purpose |
|--------|---------|
| `Scripts/Smoke/Update-SEPMExceptionPolicy/batch.ps7.ps1` | Full test matrix on PS7 (35 tests) |
| `Scripts/Smoke/Update-SEPMExceptionPolicy/batch.ps51.ps1` | Full test matrix on PS5.1 (35 tests) |
| `Scripts/Smoke/Update-SEPMExceptionPolicy/metadata.ps7.ps1` | Quick smoke (enable/disable/desc only) |

Smoke scripts are organized by cmdlet under `Scripts/Smoke/<CmdletName>/`.
Each cmdlet directory has `batch.ps7.ps1`, `batch.ps51.ps1`, and optional helpers.

Both batch scripts use a shared `T`/`Get-PolicyState` helper pattern with `Invoke-SepmApi` for GET verification.
Only the preamble differs (cert setup, module path).

```bash
# PS7
pwsh -NoProfile -File Scripts/Smoke/Update-SEPMExceptionPolicy/batch.ps7.ps1

# PS5.1
cp -r ./Output/PSSymantecSEPM /home/douda/Windows/PSSymantecSEPM
cp Scripts/Smoke/Update-SEPMExceptionPolicy/batch.ps51.ps1 /home/douda/Windows/smoke-ps51.ps1
# Note: invoke-winrm.py defaults to SSL/5986 (broken). Use NTLM/5985:
python3 -c "
import winrm
s = winrm.Session('localhost:5985', auth=('smokeuser','smokepassword'), transport='ntlm')
r = s.run_cmd('powershell -ExecutionPolicy Bypass -File \"C:\\\\Users\\\\smokeuser\\\\Desktop\\\\Shared\\\\smoke-ps51.ps1\"')
print(r.std_out.decode())
"
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
