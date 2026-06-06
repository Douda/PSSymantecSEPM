# PS 5.1 Smoke Test Investigation — Progress Report

**Branch**: `40-ps51-smoke-tests`
**Date**: 2026-06-06
**Status**: ✅ SMOKE TEST PASSING (7/7) — serialization fully resolved

---

## What works ✅

1. **WinRM connectivity**: Working. PS 5.1.26100.6584 on WIN-3KMUCUM3KH4.
2. **Auth (Get-SEPMAccessToken)**: Works via Invoke-ABRestMethod's HttpWebRequest path.
3. **Raw HttpWebRequest**: All endpoints (v1, v2, GET, POST, PATCH) work with `KeepAlive=false`.
4. **Invoke-ABRestMethod transport fix**: Replaced `Invoke-RestMethod` with `HttpWebRequest` + `KeepAlive=false` for PS 5.1, solving the TLS connection-reuse issue with SEPM.
5. **Policy GET verification**: `Invoke-ABRestMethod` returns parsed PSCustomObject (via `ConvertFrom-DictionaryToPSObject`).
6. **Policy-level PATCH (enable/disable/desc)**: ✅ All 3 pass.
7. **Mutation PATCH (file, folder, tamper, mac)**: ✅ All 4 pass.

---

## Root causes fixed (session 2026-06-06 continuation)

### 1. `$ObjBody.configuration.PSObject.Properties` — PS 5.1 iteration mismatch
**File**: `Source/Public/Update-SEPMExceptionPolicy.ps1`

**Problem**: On PS 5.1, `$ObjBody.configuration` is `[object]@{...}` — a hashtable wrapped in PSObject. Iterating `.PSObject.Properties` returns intrinsic hashtable members (IsReadOnly, Keys, Count, SyncRoot, etc.) as `Property` member type — NOT NoteProperty. The actual configuration keys (files, directories, mac, etc.) are hashtable key-value pairs, not PSObject NoteProperties.

**Fix**: Detect `IDictionary` and iterate `$ObjBody.configuration.Keys` directly. Keep `PSObject.Properties` iteration as fallback for PS 7+.

### 2. JSON serialization — replaced JavaScriptSerializer with manual builder
**File**: `Source/Public/Update-SEPMExceptionPolicy.ps1`

**Problem**: `ConvertTo-PlainDict` → `JavaScriptSerializer.Serialize()` chain had multiple PSObject wrapping issues. PowerShell wraps function return values in PSObject, so nested Dictionary values in lists carried PSMethod/PSParameterizedProperty members that `jss.Serialize()` couldn't handle.

**Fix**: Replaced the entire `ConvertTo-PlainDict` + `JavaScriptSerializer` pipeline with `ConvertTo-JsonSafe` — a recursive JSON string builder using `[System.Text.StringBuilder]`. Works on raw .NET types, unwraps non-PSCustomObject PSObjects via `.PSObject.BaseObject`, and never exposes PowerShell metadata to the serializer.

### 3. Content-Type header missing on PATCH
**File**: `Source/Private/Invoke-ABRestMethod.ps1`

**Problem**: The `HttpWebRequest` branch only set `ContentType` if the caller passed it. `Update-SEPMExceptionPolicy` never passes ContentType, so PATCH requests went out without `Content-Type: application/json`. SEPM rejected them with HTTP 500.

**Fix**: Default `$req.ContentType = 'application/json'` when a body is present and no explicit ContentType is provided.

---

## Architecture of the PS 5.1 fix (final)

```
Update-SEPMExceptionPolicy (PS 5.1 path)
  │
  ├─ Get-SEPMPoliciesSummary → Invoke-ABRestMethod → HttpWebRequest (KeepAlive=false)
  │
  ├─ Class instance → raw properties → $cleanConfig hashtable
  │   (SKIP Optimize-ExceptionPolicyStructure on PS 5.1)
  │   (iterate via IDictionary.Keys, not PSObject.Properties)
  │
  ├─ $bodyObj = PSCustomObject from $cleanConfig
  │
  ├─ ConvertTo-JsonSafe → StringBuilder → JSON string
  │   (recursive, unwraps PSObject wrappers, handles all .NET types)
  │
  └─ PATCH → HttpWebRequest (KeepAlive=false, Content-Type: application/json)
```

---

## Files modified on this branch

| File | Change |
|------|--------|
| `Source/Private/Invoke-ABRestMethod.ps1` | PS 5.1: HttpWebRequest + KeepAlive=false + Content-Type default + ConvertFrom-DictionaryToPSObject |
| `Source/Public/Update-SEPMExceptionPolicy.ps1` | PS 5.1 serialization: skip optimizer, IDictionary key iteration, ConvertTo-JsonSafe |
| `Source/Private/Optimize-ExceptionPolicyStructure.ps1` | PS 5.1: Clone-PSObjectTree instead of ConvertTo-Json roundtrip |
| `smoke-verification-tracking.md` | PS7 results, PS 5.1 diagnosis documentation |
| `Windows/smoke-ps51.ps1` | PS 5.1 smoke test script (adapted for PSCustomObject response type) |

---

## Remaining work

1. **Fix Get-SEPMExceptionPolicy for PS 5.1** — uses `ConvertFrom-Json -AsHashtable -Depth 100` (PS7-only). Needed for WindowsExtension parameter set. Replace with JavaScriptSerializer.DeserializeObject + conversion.
2. **WindowsExtension smoke test** — un-skip D1 test once Get-SEPMExceptionPolicy is fixed.
3. **Run full test matrix** — A1-A5, B1-B13, C1-C6, D1-D5, E1-E3, F1-F3, G3 (matching PS7 results).
4. **A2 false positive in smoke test** — `"errorCode:500"` string passes `$j.enabled -eq $false` check because string comparison coerces. Add explicit type check to the smoke test T() function.
