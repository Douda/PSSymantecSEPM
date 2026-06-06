# SEPM Local Smoke Testing Guide for AI Agents

## Environment

| Component | Detail |
|-----------|--------|
| **SEPM VM** | Docker container `omarchy-windows` (dockur/windows) |
| **SEPM API** | `https://localhost:8446/sepm/api/v1` (v1) / `v2` |
| **SEPM Version** | 14.3.25029.9000 (API 14.3.9000) |
| **Credentials** | `admin` / `Aurelien1!` (domain: empty string `""`) |
| **WinRM (PS 5.1)** | SSL transport, port 5986, cert validation disabled |
| **Host** | Omarchy/Arch Linux |

## Quick Connectivity Check

```bash
# Is the VM running?
docker ps --filter name=omarchy-windows

# Is SEPM responding?
curl -sk https://localhost:8446/sepm/api/v1/version
# Expected: {"API_SEQUENCE":"240604011","API_VERSION":"14.3.9000","version":"14.3.25029.9000"}
```

If the VM is not running: `docker start omarchy-windows`

## Full API Auth (curl)

```bash
TOKEN=$(curl -sk -X POST "https://localhost:8446/sepm/api/v1/identity/authenticate" \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"Aurelien1!","appName":"curl-test","domain":""}' \
  | pwsh -NoProfile -Command '$i=$input|Out-String;($i|ConvertFrom-Json).token')

# Use token:
# curl -sk "https://localhost:8446/sepm/api/v2/policies/summary" -H "Authorization: Bearer $TOKEN"
```

Token lasts ~24h (server returns `tokenExpiration` in seconds from now).

## Module Build & Import (PS 7)

```powershell
# Build from source
cd /home/douda/Documents/Projects/PSSymantecSEPM
pwsh -NoProfile -Command '
Import-Module ModuleBuilder -Force
Build-Module -SourcePath ./Source/PSSymantecSEPM.psd1 -SemVer 0.0.1
'

# Import and configure
pwsh -NoProfile -Command '
# Write config
$cfg = @{ port = 8446; ServerAddress = "localhost" } | ConvertTo-Json
$cfg | Set-Content -Path "$env:HOME/.config/PSSymantecSEPM/config.json" -Force

# Clear stale token cache
Remove-Item "$env:HOME/.local/share/PSSymantecSEPM/accessToken.xml" -Force -ErrorAction SilentlyContinue

# Import
Import-Module ./Output/PSSymantecSEPM/PSSymantecSEPM.psm1 -Force

# REQUIRED: set SkipCert in module scope (Test-SEPMCertificate is disabled)
$mod = Get-Module PSSymantecSEPM
& $mod { $script:SkipCert = $true }

# Verify
Get-SEPMVersion
Get-SEPMAccessToken
'
```

## Available Test Policy

Currently only one exception policy exists on this SEPM instance:

| Name | ID | Type |
|------|----|------|
| `Exceptions policy` | `4C4BC60CAC1E00027A25369C305828F9` | exceptions |

Use this for live mutation tests. The policy starts with 0 file exceptions.

### Verifying exception policy state (curl)

```bash
TOKEN="..."  # get fresh token first
curl -sk "https://localhost:8446/sepm/api/v2/policies/exceptions/4C4BC60CAC1E00027A25369C305828F9" \
  -H "Authorization: Bearer $TOKEN" | python3 -c "
import json, sys
data = json.load(sys.stdin)
files = data.get('configuration', {}).get('files', [])
print(f'Files: {len(files)}')
for f in files:
    print(f'  {f.get(\"path\")}  deleted={f.get(\"deleted\")}  SONAR={f.get(\"SONAR\",f.get(\"sonar\"))}')
"
```

### Verifying via PowerShell (raw GET, avoids ConvertFrom-Json double-parse bug)

```powershell
$session = Initialize-SEPMSession
$URI = $session.BaseURLv2 + "/policies/exceptions/4C4BC60CAC1E00027A25369C305828F9"
$params = @{ Session = $session; Method = 'GET'; Uri = $URI }
$resp = Invoke-ABRestMethod -params $params
$resp.configuration.files  # foreach: $_.path, $_.deleted
```

### Adding/removing an exception via curl (ground truth)

```bash
TOKEN="..."  # get fresh token

# ADD a file exception
curl -sk -X PATCH \
  "https://localhost:8446/sepm/api/v2/policies/exceptions/4C4BC60CAC1E00027A25369C305828F9" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"configuration":{"files":[{"pathvariable":"[NONE]","scancategory":"AllScans","rulestate":{"source":"PSSymantecSEPM","enabled":true},"path":"C:\\Temp\\TestSmoke.exe","deleted":false,"securityrisk":true,"applicationcontrol":true,"sonar":true}]},"name":"Exceptions policy"}'

# REMOVE a file exception (set deleted:true)
curl -sk -X PATCH \
  "https://localhost:8446/sepm/api/v2/policies/exceptions/4C4BC60CAC1E00027A25369C305828F9" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"configuration":{"files":[{"pathvariable":"[NONE]","scancategory":"AllScans","rulestate":{"source":"PSSymantecSEPM","enabled":true},"path":"C:\\Temp\\TestSmoke.exe","deleted":true,"securityrisk":true,"applicationcontrol":true,"sonar":true}]},"name":"Exceptions policy"}'
```

Successful PATCH returns HTTP 200 with empty body.

## PS 5.1 Testing (WinRM)

The Windows VM has WinRM on port 5986 (SSL transport). The `pywinrm` Python package is pre-installed in the devcontainer.

```bash
# Prerequisites (set on host before opening devcontainer):
export WINRM_USER=Administrator
export WINRM_PASS=Aurelien1!

# 1. Deploy module to shared volume
cp -r ./Output/PSSymantecSEPM /home/douda/Windows/PSSymantecSEPM

# 2. Run a test script on the VM
python3 Scripts/invoke-winrm.py 'C:\Users\Administrator\Desktop\Shared\test-script.ps1'
```

### PS 5.1 test script template

Create the script with **UTF-8 BOM** (required for PS 5.1 to parse Unicode correctly):

```bash
# Write with BOM
printf '\xef\xbb\xbf' > /home/douda/Windows/test-smoke.ps1
cat >> /home/douda/Windows/test-smoke.ps1 << 'PSEOF'
$ErrorActionPreference = "Continue"
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

# Config
$cfgPath = "$env:APPDATA\PSSymantecSEPM\config.json"
New-Item -ItemType Directory -Path (Split-Path $cfgPath) -Force | Out-Null
@{ port = 8446; ServerAddress = "10.0.2.2" } | ConvertTo-Json | Set-Content $cfgPath -Force
# NOTE: "10.0.2.2" = Docker host from QEMU guest perspective

Import-Module C:\Users\Administrator\Desktop\Shared\PSSymantecSEPM\PSSymantecSEPM.psm1 -Force

# Verify
Get-SEPMVersion
Get-SEPMExceptionPolicy -PolicyName "Exceptions policy" -List files
PSEOF
```

Then run:
```bash
python3 Scripts/invoke-winrm.py 'C:\Users\Administrator\Desktop\Shared\test-smoke.ps1'
```

**Important PS 5.1 differences:**
- No `-SkipCertificateCheck` — use `[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }`
- Host IP is `10.0.2.2` (QEMU user-mode networking gateway, maps to Docker host)
- All script files on shared volume must have UTF-8 BOM prefix (`\xef\xbb\xbf`)
- `ConvertFrom-Json` does NOT have `-AsHashtable` nor `-Depth` parameters

## Running the Smoke Test Script

A smoke test script exists at `Scripts/smoke-test-exception-policy.ps1`. It does:
1. Config setup → module import → auth
2. Basic connectivity smoke (Get-SEPMVersion)
3. Exception policy: add file → verify → remove → verify

```bash
cd /home/douda/Documents/Projects/PSSymantecSEPM
pwsh -NoProfile -File Scripts/smoke-test-exception-policy.ps1
```

## Known Bugs & Quirks

### 1. `Invoke-ABRestMethod` — `Session` key must be removed before splatting
**Fixed in this PR branch.** The `Session` key in `$params` was passed through to `Invoke-RestMethod`, where PowerShell partial-matched it to `-SessionVariable` parameter, causing an infinite "Cannot find drive" error loop.

### 2. `Initialize-SEPMSession` — `Content` vs `Content-Type` header
**Fixed in this PR branch.** The session header used `Content` (wrong HTTP header name) instead of `'Content-Type'` (correct, must be quoted due to hyphen). This caused PATCH/POST requests to return HTTP 500.

### 3. `SEPMPolicyExceptionsStructure` class location
**Fixed in this PR branch.** The class was in `Source/Classes/` which ModuleBuilder doesn't process. Moved to `Source/Private/00_Exceptions-Policy.ps1` with `00_` prefix so it loads first in the `.psm1`. Original in `Source/Classes/` was deleted to avoid duplicate definition.

### 4. `Update-SEPMExceptionPolicy` — HTTP 500 on PATCH (ACTIVE BUG)
**NOT fixed.** The cmdlet still returns HTTP 500 from SEPM API despite the request body format looking correct (the same body works via curl). Likely causes:
- Different header set between PowerShell and curl
- Character encoding differences (BOM, line endings)
- Something in the `Invoke-ABRestMethod` path that modifies the request
- **Debug approach**: compare raw request via Fiddler/mitmproxy or add request logging

### 5. `Get-SEPMExceptionPolicy` — double `ConvertFrom-Json`
**Pre-existing bug.** `Invoke-RestMethod` auto-deserializes JSON on PS 7+, then the cmdlet calls `ConvertFrom-Json` again on the already-deserialized object. For verification, use raw GET via `Invoke-ABRestMethod` directly (see example above).

### 6. `Get-SEPComputers` — infinite loop on error
**Mitigated by fix #1.** The `do..until($resp.lastPage)` loop never terminates when `$resp` is an error string (since `$null -eq $true` is always `$false`). Fix #1 prevents the error from happening.

## Test Credentials

```
Username: admin
Password: Aurelien1!
Domain:   (empty)
```

These are stored in the VM environment (docker-compose) and in `~/.config/PSSymantecSEPM/creds.xml` (encrypted via Export-Clixml).

## File Layout Reference

```
~/.config/PSSymantecSEPM/config.json     # ServerAddress + port (JSON)
~/.config/PSSymantecSEPM/creds.xml       # Encrypted credentials (Clixml)
~/.local/share/PSSymantecSEPM/accessToken.xml  # Cached token (Clixml)
~/Windows/                               # Shared volume with Windows VM
Source/Private/00_Exceptions-Policy.ps1  # PowerShell class (must load first)
Source/Private/Invoke-ABRestMethod.ps1   # REST layer (PS version switch)
Source/Private/Initialize-SEPMSession.ps1 # Session factory
Scripts/smoke-test-exception-policy.ps1  # Live smoke test script
Scripts/invoke-winrm.py                  # PS 5.1 test runner
Output/PSSymantecSEPM/                   # Built module output
```
