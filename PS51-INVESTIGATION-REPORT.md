# PS 5.1 Smoke Test Investigation — Progress Report

**Branch**: `40-ps51-smoke-tests`
**Date**: 2026-06-06
**Status**: IN PROGRESS — core connectivity solved, serialization partially fixed

---

## What works ✅

1. **WinRM connectivity**: Working. PS 5.1.26100.6584 on WIN-3KMUCUM3KH4.
2. **Auth (Get-SEPMAccessToken)**: Works via Invoke-ABRestMethod's HttpWebRequest path.
3. **Raw HttpWebRequest**: All endpoints (v1, v2, GET, POST, PATCH) work with `KeepAlive=false`.
4. **Invoke-ABRestMethod transport fix**: Replaced `Invoke-RestMethod` with `HttpWebRequest` + `KeepAlive=false` for PS 5.1, solving the TLS connection-reuse issue with SEPM.
5. **Policy GET verification**: `Invoke-ABRestMethod` returns parsed PSCustomObject (via `ConvertFrom-DictionaryToPSObject`).
6. **Policy-level PATCH (enable/disable)**: Bodies serialize correctly with the `ConvertTo-PlainDict` fix.

## What was fixed 🔧

### 1. `Invoke-ABRestMethod` — HttpWebRequest transport (PS 5.1)
**File**: `Source/Private/Invoke-ABRestMethod.ps1`
- Replaced `Invoke-RestMethod` in the `default` (PS 5.1) branch with `[System.Net.HttpWebRequest]`
- Sets `KeepAlive=false` to force fresh TLS handshake for every call
- Handles restricted headers (Authorization set via property, Content-Type skipped)
- Reads error response bodies from WebException for 4xx/5xx
- Parses JSON responses via JavaScriptSerializer → `ConvertFrom-DictionaryToPSObject`
- Added `ConvertFrom-DictionaryToPSObject` helper with `-Force` on Add-Member (SEPM returns both `sonar` and `SONAR` keys)

### 2. `Update-SEPMExceptionPolicy` — PS 5.1 serialization fixes
**File**: `Source/Public/Update-SEPMExceptionPolicy.ps1`
- **`ConvertTo-PlainDict` PSCustomObject handling**: Changed from `$obj.Keys` (doesn't exist on PSCustomObject) to `$obj.PSObject.Properties` with NoteProperty filter
- **Omitted empty `configuration`**: When `$cleanConfig` is empty (no mutations), don't include `configuration` key in body — SEPM rejects `"configuration":{}` with HTTP 500
- **Null guard on configuration**: Added `$null` check for `$ObjBody.configuration` (optimizer may remove it)
- **Added PSObject type check**: `ConvertTo-PlainDict` now handles `PSObject` (not just `PSCustomObject`)

### 3. `Optimize-ExceptionPolicyStructure` — PS 5.1 clone fix
**File**: `Source/Private/Optimize-ExceptionPolicyStructure.ps1`
- Replaced `ConvertTo-Json | ConvertFrom-Json` roundtrip (which truncates at depth 2 on PS 5.1) with `Clone-PSObjectTree` recursive cloner
- Cloner filters to `NoteProperty` and `Property` member types to avoid PSParameterizedProperty circular refs

## What's still broken ❌

### 1. Circular reference in `ConvertTo-PlainDict` → `JavaScriptSerializer.Serialize()`
**Symptom**: `"A circular reference was detected while serializing an object of type 'System.Management.Automation.PSParameterizedProperty'."`

**Root cause identified**: The PS 5.1 serialization loop iterates `$ObjBody.configuration.PSObject.Properties` without filtering to NoteProperty-only. The raw class instance (`SEPMPolicyExceptionsStructure`) has PSParameterizedProperty members that get into `$cleanConfig` → `$plainObject` → `jss.Serialize()`.

**Last attempted fix** (incomplete): Skipped `Optimize-ExceptionPolicyStructure` on PS 5.1 to avoid its `Select-Object` corruption of nested arrays. But the serialization loop still doesn't filter to NoteProperty.

**Required fix**: Add `if ($prop.MemberType -eq 'NoteProperty')` filter to the PS 5.1 serialization loop:
```powershell
foreach ($prop in $ObjBody.configuration.PSObject.Properties) {
    if ($prop.MemberType -ne 'NoteProperty') { continue }  # <-- ADD THIS
    $val = $prop.Value
    ...
}
```

### 2. WindowsExtension test SKIPPED
`Get-SEPMExceptionPolicy` uses `ConvertFrom-Json -AsHashtable -Depth 100` which is PS7-only. The extension parameter set in `Update-SEPMExceptionPolicy` calls `Get-SEPMExceptionPolicy` to read existing extensions. **Fix needed**: Add PS 5.1 fallback in `Get-SEPMExceptionPolicy`.

### 3. A1 (enable) / A3 (desc+enable) intermittent failures
The first PATCH call after auth sometimes silently fails (body correct but SEPM doesn't apply change). The second call succeeds. **Cause unknown** — may be SEPM server timing or session state issue. Needs investigation after serialization is fixed.

## Architecture of the PS 5.1 fix

```
Update-SEPMExceptionPolicy (PS 5.1 path)
  │
  ├─ Get-SEPMPoliciesSummary → Invoke-ABRestMethod → HttpWebRequest (KeepAlive=false)
  │
  ├─ Class instance → raw properties → $cleanConfig hashtable
  │   (SKIP Optimize-ExceptionPolicyStructure on PS 5.1)
  │
  ├─ $bodyObj = PSCustomObject from $cleanConfig
  │
  ├─ ConvertTo-PlainDict → Dictionary<string,object>
  │   (filters NoteProperty only, handles PSObject + PSCustomObject)
  │
  └─ JavaScriptSerializer.Serialize → JSON body → PATCH
      │
      └─ Invoke-ABRestMethod → HttpWebRequest (KeepAlive=false)
```

## Files modified on this branch

| File | Change |
|------|--------|
| `Source/Private/Invoke-ABRestMethod.ps1` | PS 5.1: HttpWebRequest + ConvertFrom-DictionaryToPSObject |
| `Source/Public/Update-SEPMExceptionPolicy.ps1` | PS 5.1 serialization: skip optimizer, fix ConvertTo-PlainDict, omit empty config, null guard |
| `Source/Private/Optimize-ExceptionPolicyStructure.ps1` | PS 5.1: Clone-PSObjectTree instead of ConvertTo-Json roundtrip |
| `smoke-verification-tracking.md` | PS7 results, PS 5.1 diagnosis documentation |
| `Windows/smoke-ps51.ps1` | PS 5.1 smoke test script (adapted for PSCustomObject response type) |

## Next steps

1. **Add NoteProperty filter to PS 5.1 serialization loop** — one-line fix to resolve circular reference
2. **Re-run smoke tests** — expect B1 (file), C1 (folder), E1 (tamper), F1 (mac) to pass
3. **Debug A1/A3 intermittent failures** — may need response checking or retry logic
4. **Fix Get-SEPMExceptionPolicy for PS 5.1** — replace `-AsHashtable -Depth` with JavaScriptSerializer
5. **Run full test matrix** matching PS7 results (A1-A5, B1-B13, C1-C6, D1-D5, E1-E3, F1-F3, G3)
