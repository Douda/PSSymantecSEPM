# Update-SEPMExceptionPolicy — Final Smoke Verification Matrix

Test policy: `Exceptions policy` (ID: `4C4BC60CAC1E00027A25369C305828F9`)
Date: 2026-06-06
**Result: 35/35 PS7, 35/35 PS5.1**

## Run Commands

```bash
# PS7
pwsh -NoProfile -File Scripts/Smoke/Update-SEPMExceptionPolicy/batch.ps7.ps1

# PS5.1 (deploy first)
rm -rf /home/douda/Windows/PSSymantecSEPM
cp -r ./Output/PSSymantecSEPM /home/douda/Windows/PSSymantecSEPM
cp Scripts/Smoke/Update-SEPMExceptionPolicy/batch.ps51.ps1 /home/douda/Windows/smoke-ps51.ps1
# invoke-winrm.py now defaults to smokeuser/smokepassword NTLM/5985
python3 Scripts/invoke-winrm.py 'C:\Users\smokeuser\Desktop\Shared\smoke-ps51.ps1'
```

## Results

| # | Group | Test | Key Assertion | PS7 | PS5.1 |
|---|-------|------|---------------|-----|-------|
| A1 | Default | EnablePolicy | enabled=true | 🟢 | 🟢 |
| A2 | Default | DisablePolicy | enabled=false | 🟢 | 🟢 |
| A3 | Default | PolicyDescription | desc set + enabled=true | 🟢 | 🟢 |
| A4 | Default | Enable+Description | enabled=true, desc set | 🟢 | 🟢 |
| A5 | Default | Enable+Disable | mutual exclusivity error | 🟢 | 🟢 |
| B1 | WindowsFile | Default (AllScans) | sonar/sec/appctrl all true, scancat=AllScans | 🟢 | 🟢 |
| B2 | WindowsFile | Explicit AllScans | same as B1 | 🟢 | 🟢 |
| B3 | WindowsFile | Sonar only | sonar=true, sec≠true, appctrl≠true | 🟢 | 🟢 |
| B4 | WindowsFile | SecurityRisk AutoProtect | sec=true, scancat=AutoProtect, sonar≠true | 🟢 | 🟢 |
| B5 | WindowsFile | ApplicationControl only | appctrl=true | 🟢 | 🟢 |
| B6 | WindowsFile | AC + ExcludeChild | appctrl=true, recursive=true | 🟢 | 🟢 |
| B7 | WindowsFile | Sonar + AC | sonar=true, appctrl=true, sec≠true | 🟢 | 🟢 |
| B8 | WindowsFile | Sonar + SecurityRisk | sonar/sec=true, scancat=ScheduledAndOndemand | 🟢 | 🟢 |
| B9 | WindowsFile | PathVariable [SYSTEM] | pathvariable=[SYSTEM] | 🟢 | 🟢 |
| B10 | WindowsFile | Remove | entry absent from GET | 🟢 | 🟢 |
| B12 | WindowsFile | AllScans + EnablePolicy | rule + enabled=true | 🟢 | 🟢 |
| B13 | WindowsFile | AllScans + Description | rule + desc set | 🟢 | 🟢 |
| C1 | WindowsFolder | Default All | scantype=All | 🟢 | 🟢 |
| C2 | WindowsFolder | ScanType SONAR | scantype=SONAR | 🟢 | 🟢 |
| C3 | WindowsFolder | SecurityRisk + AutoProtect | scantype=SecurityRisk, scancat=AutoProtect | 🟢 | 🟢 |
| C4 | WindowsFolder | IncludeSubFolders | recursive=true | 🟢 | 🟢 |
| C5 | WindowsFolder | Remove | entry absent | 🟢 | 🟢 |
| C6 | WindowsFolder | Incompatible params | validation error | 🟢 | 🟢 |
| D1 | WindowsExtension | Add extension (merge) | extension in list, scancat=AllScans | 🟢 | 🟢 |
| D2 | WindowsExtension | Add again (dedup) | 1 copy only | 🟢 | 🟢 |
| D3 | WindowsExtension | Remove | extension absent | 🟢 | 🟢 |
| D4 | WindowsExtension | Remove nonexistent | validation error | 🟢 | 🟢 |
| D5 | WindowsExtension | ScanType AutoProtect | scancat=AutoProtect | 🟢 | 🟢 |
| E1 | Tamper | Basic add | path set, pathvar=[NONE] | 🟢 | 🟢 |
| E2 | Tamper | PathVariable [SYSTEM] | pathvar=[SYSTEM] | 🟢 | 🟢 |
| E3 | Tamper | Remove | entry absent | 🟢 | 🟢 |
| F1 | MacFile | Basic add | path set, pathvar=[NONE] | 🟢 | 🟢 |
| F2 | MacFile | PathVariable [HOME] | pathvar=[HOME] | 🟢 | 🟢 |
| F3 | MacFile | Remove | entry absent | 🟢 | 🟢 |
| G3 | Error | NonExistentPolicy | client-side validation error | 🟢 | 🟢 |

**PS7: 35/35 PASS | PS5.1: 35/35 PASS**

## Key API Findings

1. **Remove behavior**: SEPM removes entries entirely when `deleted=true` — no tombstone.
2. **Directory paths**: API appends trailing `\`.
3. **Enum values**: API accepts human-readable scan type/category values.
4. **Duplicate JSON keys**: `sonar`/`SONAR` appear in policy responses. `Invoke-SepmApi` uses `-AsHashtable` (PS7) and `JavaScriptSerializer` (PS5.1) as tolerant parsers.
5. **Unset booleans**: API converts null booleans to `false` in the response.
6. **PathVariable**: Full paths sent; SEPM resolves variables server-side.

## Transport Architecture

| Runtime | Auth | Data |
|---------|------|------|
| PS7 | Invoke-RestMethod | Invoke-RestMethod + ConvertFrom-Json -AsHashtable |
| PS5.1 | Invoke-RestMethod | HttpWebRequest + KeepAlive=false + JavaScriptSerializer |

`Invoke-SepmApi` (`Source/Private/Invoke-SepmApi.ps1`) encapsulates this split.
`Get-SEPMExceptionPolicy` uses `Invoke-SepmApi` + `ConvertTo-Hashtable` (PS5.1 PSCustomObject→hashtable conversion for indexer compat).

## PS5.1-Specific Notes

- Certificate bypass: `[ServerCertificateValidationCallback] = { $true }`
- TLS: Force `Tls12` via `[SecurityProtocol]`
- Encoding: Files deployed to shared volume must have UTF-8 BOM (`\xef\xbb\xbf`)
- `ConvertFrom-Json` lacks `-AsHashtable`/`-Depth` — use `JavaScriptSerializer`
- `Invoke-RestMethod` Keep-Alive breaks after auth POST — use `HttpWebRequest` with `KeepAlive=false`
