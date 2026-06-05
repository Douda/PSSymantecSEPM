# Auth preamble concentrated into Initialize-SEPMSession

Every public cmdlet in the module duplicated the same 8-line auth preamble (token
validation, renewal, certificate bypass, header assembly). This was spread across ~50
files — any change to auth logic required editing all of them.

We extracted this into a single `Initialize-SEPMSession` module in Private/. It
validates/renews the token, applies the certificate bypass, and returns a session context
object (`Headers`, `BaseURLv1`, `BaseURLv2`). Callers use `$session.Headers` instead of
constructing auth headers from `$script:accessToken`.

**Why a context object, not silent script-scope side effects:** the session object hides
token format and header assembly from callers. If SEPM changes its auth header format,
only `Initialize-SEPMSession` needs to change — not every cmdlet that makes API calls.
