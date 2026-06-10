# Consolidate on Invoke-SepmApi; deepen with -Session parameter

The module had two REST transports: deprecated `Invoke-ABRestMethod` (51 call sites) and its
replacement `Invoke-SepmApi` (4 call sites). We migrated all callers to `Invoke-SepmApi`,
deleted the old transport, and added a `-Session` parameter so callers don't need to know
the session's internal shape (`Headers`, `SkipCert`). This restores ADR-0001's design intent:
"The session object hides token format and header assembly from callers."

## Considered options

- **Single `-Session` parameter, no escape hatch.** Rejected — `Get-SEPMAccessToken` is the
  auth bootstrap; it calls `/identity/authenticate` before a session exists. It needs
  header-level control.
- **`-Headers`/`-SkipCert` as optional overrides alongside `-Session`.** Rejected — non-
  mutually-exclusive params with fallback logic are confusing. The parameter set split
  (`-Session` xor `-Headers`/`-SkipCert`) documents the design intent: you either have a
  session or you don't.

## Consequences

- `Invoke-ABRestMethod.ps1` and `ConvertFrom-DictionaryToPSObject.ps1` deleted.
- `Invoke-SepmApi` returns `[hashtable]` uniformly across PS versions (was `PSCustomObject`).
  `ConvertTo-Hashtable` handles both `PSCustomObject` and `IDictionary` → no intermediate type.
- `To_Update/` directory deleted — all three files were dead code excluded from the module build.
