# SEPM Smoke Testing

## Environment

| What | Value |
|------|-------|
| VM container | `omarchy-windows` (dockur/windows) |
| SEPM API | `https://localhost:8446/sepm/api/v{1,2}` |
| SEPM version | 14.3.25029.9000 |
| Credentials | `admin` / `Aurelien1!` / domain: `""` |
| WinRM (PS 5.1) | SSL transport, port 5986, `172.17.0.1` |
| Shared volume | `/home/douda/Windows/` ↔ `C:\Users\Administrator\Desktop\Shared\` |

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
  -d '{"username":"admin","password":"Aurelien1!","appName":"test","domain":""}' \
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

### Verify state (PS 7, avoids Get-SEPMExceptionPolicy double-parse bug)

```powershell
$s = Initialize-SEPMSession
$p = @{Session=$s;Method='GET';Uri=$s.BaseURLv2+'/policies/exceptions/4C4BC60CAC1E00027A25369C305828F9'}
$r = Invoke-ABRestMethod -params $p
$r.enabled; $r.desc; $r.configuration.files
```

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
$cfg="$env:APPDATA\PSSymantecSEPM\config.json"
New-Item -ItemType Directory (Split-Path $cfg) -Force|Out-Null
@{port=8446;ServerAddress="10.0.2.2"}|ConvertTo-Json|Set-Content $cfg -Force
Import-Module C:\Users\Administrator\Desktop\Shared\PSSymantecSEPM\PSSymantecSEPM.psm1 -Force
$mod=Get-Module PSSymantecSEPM; & $mod {$script:SkipCert=$true}
Get-SEPMVersion
# ... test commands ...
EOF

# Run (env vars needed)
WINRM_USER=Administrator WINRM_PASS=Aurelien1! python3 Scripts/invoke-winrm.py \
  'C:\Users\Administrator\Desktop\Shared\test-ps51.ps1'
```

**PS 5.1 differences**: no `-SkipCertificateCheck` (use callback above); host IP is `10.0.2.2` (QEMU→Docker host); all .ps1 files need UTF-8 BOM; `ConvertFrom-Json` lacks `-AsHashtable`/`-Depth`.

## Smoke scripts

| Script | Purpose |
|--------|---------|
| `Scripts/smoke-test-exception-policy.ps1` | Build→import→auth→add file→verify→remove→verify |
| `Scripts/smoke-metadata-ps7.ps1` | Enable/Disable/Description metadata mutations |

```bash
pwsh -NoProfile -File Scripts/smoke-test-exception-policy.ps1
pwsh -NoProfile -File Scripts/smoke-metadata-ps7.ps1
```

## Known bugs

### 1. `Update-SEPMExceptionPolicy` — PATCH with `configuration` body fails (ACTIVE)

**Symptom**: PATCH returns HTTP 200, but GET shows no changes applied. Same body works via curl and `Invoke-WebRequest` directly. Metadata-only PATCHes (enable/disable/desc, no `configuration` key) work correctly through the cmdlet.

**Debug approach**: compare raw bytes sent by `Invoke-ABRestMethod` vs curl via mitmproxy/tcpdump.

### 2. `Get-SEPMExceptionPolicy` — double `ConvertFrom-Json` (pre-existing)

`Invoke-RestMethod` auto-deserializes on PS 7+, then the cmdlet calls `ConvertFrom-Json` again. For verification, use raw GET via `Invoke-ABRestMethod` (see "Verify state" above).

### 3. `Get-SEPComputers` — infinite loop on error (pre-existing)

`do..until($resp.lastPage)` never terminates when `$resp` is an error string.

## File layout

```
~/.config/PSSymantecSEPM/config.json         # {port, ServerAddress}
~/.config/PSSymantecSEPM/creds.xml           # encrypted creds (Export-Clixml)
~/.local/share/PSSymantecSEPM/accessToken.xml # cached token
~/Windows/                                   # shared with Windows VM
Source/Private/00_Exceptions-Policy.ps1      # PowerShell class (loads first)
Source/Private/Invoke-ABRestMethod.ps1       # REST layer (PS version switch)
Source/Private/Initialize-SEPMSession.ps1    # session factory
Output/PSSymantecSEPM/                       # built module
Scripts/invoke-winrm.py                      # PS 5.1 test runner
```
