# Auth preamble concentrated into Initialize-SEPMSession

Every public cmdlet in the module duplicated the same 8-line auth preamble (token
validation, renewal, certificate bypass, header assembly). This was spread across ~50
files — any change to auth logic required editing all of them.

We extract this into a single `Initialize-SEPMSession` module in Private/. It
validates/renews the token and returns a session context object.

## Session shape

`Initialize-SEPMSession` returns a `[PSCustomObject]`:

```powershell
$session = [PSCustomObject]@{
    Headers   = @{ Authorization = "Bearer $token"; Content = 'application/json' }
    BaseURLv1 = 'https://...'
    BaseURLv2 = 'https://...'
    SkipCert  = $false
}
```

Cmdlets use `$session.Headers` instead of constructing auth headers from
`$script:accessToken`. `Invoke-ABRestMethod` receives the full session object and
unpacks `SkipCert` + `Headers` internally.

## What moves into Initialize-SEPMSession

- Token lifecycle: check cached memory → check disk → query SEPM → cache to memory + disk
- Header assembly
- `$script:BaseURLv1` / `$script:BaseURLv2` (read from existing config)
- Session-wide `SkipCert` flag

## What gets deleted

- `-SkipCertificateCheck` parameter from every public cmdlet (~50 files). Cert bypass
  becomes session-wide: set once via config or module-scope variable, not per-cmdlet.
- `Test-SEPMCertificate` (private function + both call sites). It was fully commented
  out since commit e1f2178.
- `Get-SEPMAccessToken` moves from Public/ to Private/. The raw token is no longer a
  public concern — users call `Initialize-SEPMSession` instead.

## What stays unchanged (this iteration)

- Configuration mutators: `Set-SepmConfiguration`, `Set-SEPMAuthentication`,
  `Reset-SEPMConfiguration`, `Clear-SEPMAuthentication`, `Backup-*`, `Restore-*`
- `$script:configuration`, `$script:Credential`, `$script:BaseURLv1`, `$script:BaseURLv2`
  (still managed by config mutators; `Initialize-SEPMSession` reads from them)

## Caching

`Initialize-SEPMSession` caches the session in module-scope `$script:_session`. Repeated
calls within the same module session are cheap — token expiry is checked on each call and
the token is renewed transparently if expired.

## Caller pattern

Every public cmdlet calls `Initialize-SEPMSession` in `begin{}`:

```powershell
begin {
    $session = Initialize-SEPMSession
}
process {
    $params = @{
        Method  = 'GET'
        Uri     = $session.BaseURLv1 + '/computers'
        Session = $session
    }
    $resp = Invoke-ABRestMethod -params $params
}
```

## Why a context object, not silent script-scope side effects

The session object hides token format and header assembly from callers. If SEPM changes
its auth header format, only `Initialize-SEPMSession` needs to change — not every cmdlet
that makes API calls. Tests mock one function (`Initialize-SEPMSession` → return a fake
session) instead of orchestrating 7 script-scope variables.
