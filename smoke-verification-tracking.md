# Update-SEPMExceptionPolicy — Live API Verification Matrix

Test policy: `Exceptions policy` (ID: `4C4BC60CAC1E00027A25369C305828F9`)

## Legend

| Symbol | Meaning |
|--------|---------|
| ⬜ | Not yet run |
| 🟢 | PASS — fields verified in GET response |
| 🔴 | FAIL — fields wrong/missing in GET response |
| ⚫ | API rejected / HTTP error |
| 🟡 | AMBIGUOUS — needs investigation |

## Feedback loop

```
1. Run cmdlet with params
2. Raw GET policy via Invoke-ABRestMethod (bypasses double-ConvertFrom-Json)
3. Assert each expected field value
4. Record result
```

---

## PS7 Results (`Scripts/smoke-batch-ps7.ps1`)

Run: `pwsh -NoProfile -File Scripts/smoke-batch-ps7.ps1`
Date: 2026-06-06
Result: **34/35 PASS**

### A. Policy-Level Metadata

| # | Params | Expected | Result |
|---|--------|----------|--------|
| A1 | `-EnablePolicy` | `enabled = true` | 🟢 |
| A2 | `-DisablePolicy` | `enabled = false` | 🟢 |
| A3 | `-PolicyDescription "desc-A3"` | `desc = "desc-A3"`, enabled=true | 🟢 |
| A4 | `-EnablePolicy -PolicyDescription "desc-A4"` | enabled=true, desc set | 🟢 |
| A5 | `-EnablePolicy -DisablePolicy` | Throws mutual exclusivity error | 🟢 |

### B. WindowsFile

| # | Params | Key assertion | Result |
|---|--------|---------------|--------|
| B1 | `-Path C:\Temp\SmokeB1.exe` (no scan) | sonar/securityrisk/applicationcontrol all true, scancat=AllScans | 🟢 |
| B2 | `-Path C:\Temp\SmokeB2.exe -AllScans` | same as B1 | 🟢 |
| B3 | `-Path C:\Temp\SmokeB3.exe -Sonar` | sonar=true, securityrisk≠true, appctrl≠true | 🟢 |
| B4 | `-Path C:\Temp\SmokeB4.exe -SecurityRiskCategory AutoProtect` | securityrisk=true, scancat=AutoProtect, sonar≠true | 🟢 |
| B5 | `-Path C:\Temp\SmokeB5.exe -ApplicationControl` | appctrl=true, sonar≠true, sec≠true | 🟢 |
| B6 | `-Path C:\Temp\SmokeB6.exe -ApplicationControl -ExcludeChildProcesses` | appctrl=true, recursive=true | 🟢 |
| B7 | `-Path C:\Temp\SmokeB7.exe -Sonar -ApplicationControl` | sonar=true, appctrl=true, sec≠true | 🟢 |
| B8 | `-Path C:\Temp\SmokeB8.exe -Sonar -SecurityRiskCategory ScheduledAndOndemand` | sonar=true, sec=true, scancat=ScheduledAndOndemand | 🟢 |
| B9 | `-Path C:\Windows\SmokeB9.exe -PathVariable [SYSTEM]` | pathvariable=[SYSTEM] | 🟢 |
| B10 | Add then `-Remove` | Entry absent from GET response | 🟢 |
| B12 | `-Path ... -AllScans -EnablePolicy` | rule added + enabled=true | 🟢 |
| B13 | `-Path ... -AllScans -PolicyDescription "desc-B13"` | rule added + desc set | 🟢 |

### C. WindowsFolder

| # | Params | Key assertion | Result |
|---|--------|---------------|--------|
| C1 | `-FolderPath C:\Temp\SmokeFolderC1` | scantype=All | 🟢 |
| C2 | `-FolderPath C:\Temp\SmokeFolderC2 -ScanType SONAR` | scantype=SONAR | 🟢 |
| C3 | `-FolderPath C:\Temp\SmokeFolderC3 -ScanType SecurityRisk -SecurityRiskCategory AutoProtect` | scantype=SecurityRisk, scancat=AutoProtect | 🟢 |
| C4 | `-FolderPath C:\Temp\SmokeFolderC4 -IncludeSubFolders` | recursive=true | 🟢 |
| C5 | Add then `-Remove` | Entry absent | 🟢 |
| C6 | `-FolderPath ... -ScanType All -SecurityRiskCategory AllScans` | Throws validation error | 🟢 |

### D. WindowsExtension

| # | Params | Key assertion | Result |
|---|--------|---------------|--------|
| D1 | `-Extensions ".smoketest"` | Extension in list, scancat=AllScans, merged with existing | 🟢 |
| D2 | `-Extensions ".smoketest"` again | Still 1 copy (dedup) | 🟢 |
| D3 | `-Extensions ".smoketest" -Remove` | Extension absent from list | 🟢 |
| D4 | `-Extensions ".nonexistent_ext" -Remove` | Throws "not in exception list" | 🟢 |
| D5 | `-Extensions ".smoketest_d5" -ScanType AutoProtect` | scancat=AutoProtect | 🟢 |

### E. Tamper

| # | Params | Key assertion | Result |
|---|--------|---------------|--------|
| E1 | `-TamperPath C:\Temp\SmokeTamperE1.exe` | path set, pathvar=[NONE] | 🟢 |
| E2 | `-TamperPath C:\Windows\SmokeTamperE2.exe -PathVariable [SYSTEM]` | pathvar=[SYSTEM] | 🟢 |
| E3 | `-TamperPath ... -Remove` (after E1) | Entry absent | 🟢 |

### F. MacFile

| # | Params | Key assertion | Result |
|---|--------|---------------|--------|
| F1 | `-MacPath /tmp/SmokeMacF1.app` | path=/tmp/SmokeMacF1.app, pathvar=[NONE] | 🟢 |
| F2 | `-MacPath /Users/test/SmokeMacF2.app -MacPathVariable [HOME]` | pathvar=[HOME] | 🟢 |
| F3 | `-MacPath /tmp/SmokeMacF1.app -Remove` | Entry absent | 🟢 |

### G. Errors

| # | Params | Expected | Result |
|---|--------|----------|--------|
| G3 | `-PolicyName "NonExistentPolicy" -EnablePolicy` | Should error | 🔴 API returns HTTP 500 (cmdlet doesn't validate PolicyName) |

---

## Ambiguous items — RESOLVED

| ID | Question | Resolution |
|----|----------|------------|
| AMB1 | WindowsFolder ScanType: human-readable vs GEPT_* enums? | API **accepts** human-readable values (All, SONAR, SecurityRisk, ApplicationControl). Stores as-is. |
| AMB2 | Extension scancategory: "AllScans" vs GESC_*? | API **accepts** human-readable "AllScans", "AutoProtect", "ScheduledAndOndemand". No GESC_ prefix needed. |
| AMB3 | Tamper files schema: does API store sonar/securityrisk? | API stores only the fields we send. For Tamper, we send null for scan fields → API stores no scan fields on tamper entries. |
| AMB4 | MacFile: can scan-type be force-set? | `ExceptionsRuleMacFile` schema has NO scan fields. `CreateMacFilesHashtable` has no scan params. Not possible via current API. |
| AMB5 | Known bug K1 — configuration PATCH fails? | **FIXED** — configuration PATCH works correctly. All file/folder/extension/tamper/mac mutations apply and are visible in GET. |

---

## Key API behavior findings

1. **Remove behavior**: SEPM **removes entries entirely** from the array when `deleted=true` is sent. It does NOT keep them with a `deleted` flag.
2. **Directory paths**: API appends trailing `\` to directory paths (e.g., `C:\Temp\folder\`).
3. **Enum values**: API accepts human-readable scan type/category values (not just GEPT_*/GESC_* enum names).
4. **`ExceptionsRuleFile` dual field**: API returns BOTH `sonar` (lowercase) and `SONAR` (uppercase) on file entries. Both are booleans.
5. **Unset booleans**: API converts null booleans to `false` in the response.
6. **Path validation**: Cmdlet's regex requires full Windows path always — PathVariable with relative path fails validation. We send full paths and SEPM resolves via PathVariable server-side.

---

## PS 5.1 — Setup & Connectivity Reference

### WinRM access

| Item | Value |
|------|-------|
| Transport | HTTP (port 5985) |
| Host | `localhost` (mapped `0.0.0.0:5985` in docker-compose) |
| User | `douda` |
| Password | `aurelien` |
| PS version | 5.1.26100.6584 Desktop |
| Hostname | WIN-3KMUCUM3KH4 |
| Shared volume | `C:\Users\douda\Desktop\Shared\` ← `/home/douda/Windows/` |

### SEPM connectivity from inside the VM

**SEPM runs ON the Windows VM itself.** The API is at `localhost:8446` from inside the VM — NOT an external Docker host IP.

```powershell
# Required PS 5.1 preamble
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

$cfg = @{port=8446;ServerAddress="localhost"} | ConvertTo-Json
$cfg | Set-Content "$env:APPDATA\PSSymantecSEPM\config.json" -Force

Import-Module C:\Users\douda\Desktop\Shared\PSSymantecSEPM\PSSymantecSEPM.psm1 -Force
$mod = Get-Module PSSymantecSEPM
& $mod { $script:SkipCert = $true }
Get-SEPMAccessToken  # must call explicitly before using cmdlets
```

### Deploy & run

```bash
# Clean rebuild (ModuleBuilder caches stale output)
rm -rf ./Output/PSSymantecSEPM
pwsh -NoProfile -c 'Import-Module ModuleBuilder -Force; Build-Module -SourcePath ./Source/PSSymantecSEPM.psd1 -SemVer 0.0.1'

# Deploy to shared volume
cp -r ./Output/PSSymantecSEPM /home/douda/Windows/PSSymantecSEPM

# Run smoke tests
WINRM_USER=douda WINRM_PASS=aurelien python3 Scripts/invoke-winrm.py \
  'C:\Users\douda\Desktop\Shared\smoke-ps51.ps1'
```

### PS 5.1 differences from PS 7

| Feature | PS 7 | PS 5.1 |
|---------|------|--------|
| Cert bypass | `-SkipCertificateCheck` | `[ServerCertificateValidationCallback]` |
| TLS | Auto | Must force `Tls12` |
| `ConvertFrom-Json` | `-AsHashtable -Depth` | No flags; use `JavaScriptSerializer` |
| `ConvertTo-Json` | `-Depth 100` | No `-Depth`; use `JavaScriptSerializer.Serialize()` |
| SEPM address | `localhost` (devcontainer on same host) | `localhost` (SEPM runs on the VM itself) |
| Token | `Initialize-SEPMSession` auto | Call `Get-SEPMAccessToken` first |
| Encoding | UTF-8 | UTF-8 **with BOM** (`\xef\xbb\xbf`) |

### Known PS 5.1 issues

#### K2: `Invoke-RestMethod` GET fails after auth POST (HTTP Keep-Alive / TLS reuse)

**Diagnosed 2026-06-06.** `Invoke-RestMethod` on PS 5.1 uses HTTP Keep-Alive by default.
After a successful POST to `/identity/authenticate`, any subsequent request (GET or POST) to
any endpoint fails with `"The underlying connection was closed: An unexpected error occurred on a send."`
SEPM's TLS implementation appears incompatible with .NET Framework 4.x connection reuse.

**Workaround**: Use `[System.Net.HttpWebRequest]` directly with `$req.KeepAlive = $false`.
All endpoints (v1, v2, GET, POST, PATCH) work correctly when KeepAlive is disabled.

**Fix required**: `Invoke-ABRestMethod` should use `HttpWebRequest` on PS 5.1 instead of
`Invoke-RestMethod`, or force `ServicePoint` to not reuse connections.

**Verification**:
```
Auth POST via Invoke-RestMethod  -> OK (token obtained)
GET policy via Invoke-RestMethod -> FAIL (TLS send error)
GET policy via HttpWebRequest/KAFalse -> OK (full JSON returned)
GET version via HttpWebRequest/KAFalse -> OK (14.3.25029.9000)
```

#### K1: `Get-SEPMVersion` fails (same root cause as K2)

`Get-SEPMVersion` uses `Invoke-RestMethod` directly and fails with the same TLS error.

## PS 5.1 Results (`Scripts/smoke-ps51.ps1`)

Run: `WINRM_USER=douda WINRM_PASS=aurelien python3 Scripts/invoke-winrm.py 'C:\Users\douda\Desktop\Shared\smoke-ps51.ps1'`
Date: 2026-06-06
Result: **29/34 PASS** (D group blocked by #51 — `-AsHashtable` not available on PS 5.1)

### A. Policy-Level Metadata

| # | Params | Expected | Result |
|---|--------|----------|--------|
| A1 | `-EnablePolicy` | `enabled = true` | 🟢 |
| A2 | `-DisablePolicy` | `enabled = false` | 🟢 |
| A3 | `-PolicyDescription "ps51-A3"` | desc set, enabled=true | 🟢 |
| A4 | `-EnablePolicy -PolicyDescription "ps51-A4"` | enabled=true, desc set | 🟢 |
| A5 | `-EnablePolicy -DisablePolicy` | Throws mutual exclusivity error | 🟢 |

### B. WindowsFile

| # | Params | Key assertion | Result |
|---|--------|---------------|--------|
| B1 | `-Path C:\Temp\SmokeB1.exe` (no scan) | sonar/securityrisk/applicationcontrol all true, scancat=AllScans | 🟢 |
| B2 | `-Path C:\Temp\SmokeB2.exe -AllScans` | same as B1 | 🟢 |
| B3 | `-Path C:\Temp\SmokeB3.exe -Sonar` | sonar=true, securityrisk≠true, appctrl≠true | 🟢 |
| B4 | `-Path C:\Temp\SmokeB4.exe -SecurityRiskCategory AutoProtect` | securityrisk=true, scancat=AutoProtect, sonar≠true | 🟢 |
| B5 | `-Path C:\Temp\SmokeB5.exe -ApplicationControl` | appctrl=true, sonar≠true, sec≠true | 🟢 |
| B6 | `-Path C:\Temp\SmokeB6.exe -ApplicationControl -ExcludeChildProcesses` | appctrl=true, recursive=true | 🟢 |
| B7 | `-Path C:\Temp\SmokeB7.exe -Sonar -ApplicationControl` | sonar=true, appctrl=true, sec≠true | 🟢 |
| B8 | `-Path C:\Temp\SmokeB8.exe -Sonar -SecurityRiskCategory ScheduledAndOndemand` | sonar=true, sec=true, scancat=ScheduledAndOndemand | 🟢 |
| B9 | `-Path C:\Windows\SmokeB9.exe -PathVariable [SYSTEM]` | pathvariable=[SYSTEM] | 🟢 |
| B10 | Add then `-Remove` | Entry absent from GET response | 🟢 |
| B12 | `-Path ... -AllScans -EnablePolicy` | rule added + enabled=true | 🟢 |
| B13 | `-Path ... -AllScans -PolicyDescription "ps51-B13"` | rule added + desc set | 🟢 |

### C. WindowsFolder

| # | Params | Key assertion | Result |
|---|--------|---------------|--------|
| C1 | `-FolderPath C:\Temp\SmokeFolderC1` | scantype=All | 🟢 |
| C2 | `-FolderPath C:\Temp\SmokeFolderC2 -ScanType SONAR` | scantype=SONAR | 🟢 |
| C3 | `-FolderPath C:\Temp\SmokeFolderC3 -ScanType SecurityRisk -SecurityRiskCategory AutoProtect` | scantype=SecurityRisk, scancat=AutoProtect | 🟢 |
| C4 | `-FolderPath C:\Temp\SmokeFolderC4 -IncludeSubFolders` | recursive=true | 🟢 |
| C5 | Add then `-Remove` | Entry absent | 🟢 |
| C6 | `-FolderPath ... -ScanType All -SecurityRiskCategory AllScans` | Throws validation error | 🟢 |

### D. WindowsExtension

| # | Params | Key assertion | Result |
|---|--------|---------------|--------|
| D1 | `-Extensions ".ps51test"` | Extension in list, merged | 🔴 |
| D2 | `-Extensions ".ps51test"` again | Still 1 copy (dedup) | 🔴 |
| D3 | `-Extensions ".ps51test" -Remove` | Extension absent | 🔴 |
| D4 | `-Extensions ".nonexistent_ext" -Remove` | Throws validation error | 🔴 |
| D5 | `-Extensions ".ps51test_d5" -ScanType AutoProtect` | scancat=AutoProtect | 🔴 |

**D group blocked by #51**: `ConvertFrom-Json -AsHashtable` not available on PS 5.1. Extension merge/dedup logic in `Invoke-SepmApi` fails.

### E. Tamper

| # | Params | Key assertion | Result |
|---|--------|---------------|--------|
| E1 | `-TamperPath C:\Temp\SmokeTamperE1.exe` | path set, pathvar=[NONE] | 🟢 |
| E2 | `-TamperPath C:\Windows\SmokeTamperE2.exe -PathVariable [SYSTEM]` | pathvar=[SYSTEM] | 🟢 |
| E3 | `-TamperPath ... -Remove` (after E1) | Entry absent | 🟢 |

### F. MacFile

| # | Params | Key assertion | Result |
|---|--------|---------------|--------|
| F1 | `-MacPath /tmp/SmokeMacF1.app` | path set, pathvar=[NONE] | 🟢 |
| F2 | `-MacPath /Users/test/SmokeMacF2.app -MacPathVariable [HOME]` | pathvar=[HOME] | 🟢 |
| F3 | `-MacPath /tmp/SmokeMacF1.app -Remove` | Entry absent | 🟢 |

### PS 5.1 Test Status

**VERIFIED 2026-06-06**: B-group 12/12 PASS with strengthened assertions matching PS7 spec. D-group blocked by #51.
