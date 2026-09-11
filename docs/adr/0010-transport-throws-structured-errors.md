# The transport throws structured Transport Errors; it never returns failure as a value

`Invoke-SepmApi` used to catch every failure and `return "Error: $_"` — a **string**. Callers
could not tell success from failure except by matching text, and the consequences spread
throughout the module:

- `Get-SEPMFileDetails` and `Get-SEPMFileFingerprintList` handed the error string to the user
  as ordinary output.
- `Get-SEPMAccessToken` did `$response.token` on a string, got `$null`, cached that null token,
  and reported a **successful authentication**. The failure resurfaced later as `invalid_token`
  on every subsequent call.
- `Confirm-SEPMEventInfo` grew a regex on `errorCode|Failed to update` to detect failures.
- `Invoke-SepmApiPaginated` had to special-case a string return.

We now build an `ErrorRecord` with `New-SEPMApiError` and raise it with
`$PSCmdlet.ThrowTerminatingError()` from both the PS 7 and the PS 5.1 branch. All interpretation
of a failure — certificate detection, body parsing, category selection, message composition —
lives in one place, `ConvertTo-SEPMTransportError`, so the two PS branches cannot drift.

A string return now always means success (the XML policy and location endpoints return one).

## The three ErrorIds

The organising principle is **one id per remedy the operator can act on**:

- `SEPM.AuthenticationFailed` — the credential was rejected, or a 401 arrived mid-session
  because the token expired. Remedy: re-authenticate.
- `SEPM.CertificateError` — TLS validation failed. Detected, but see the note below.
- `SEPM.ApiError` — the server refused the request, or was unreachable. The `ErrorCategory`
  refines it: `InvalidData`, `ObjectNotFound`, `PermissionDenied`, `ResourceUnavailable`,
  `ConnectionError`, and so on.

`FullyQualifiedErrorId` is composed as `<ErrorId>,<ExceptionTypeName>`, so callers match with
`-like 'SEPM.ApiError*'`, not `-eq`.

`Get-SEPMAccessToken` re-tags a failure of `/identity/authenticate` as
`SEPM.AuthenticationFailed`: SEPM answers a wrong password with a generic HTTP 400, so the
transport cannot tell it apart from any other bad request. A certificate failure is passed
through untouched, because the transport already tagged it more precisely.

## Category selection is defensive, not load-bearing

The rule is: prefer the body's `errorCode`, fall back to the HTTP status. The rationale
originally recorded here was that SEPM returns HTTP 500 with `errorCode` 400 for a bad
argument. **That was a misreading of the evidence and does not reproduce.** Measuring six
failing endpoints, `errorCode` always equalled the HTTP status (500/500, 400/400, 400/400,
400/400). The rule is therefore inert today; it is kept because it costs five lines and makes
the message show both numbers when they ever do disagree. Do not cite it as a fix for a real
SEPM behaviour.

## Certificate failures are detected by exception type, not message text

The failure never reaches the API — it fails during the TLS handshake. PS 7 raises
`HttpRequestException` wrapping `System.Security.Authentication.AuthenticationException`; PS 5.1
wraps the same `AuthenticationException` inside a `WebException`. The chain is walked for that
type, with a message match only as a fallback, because .NET localizes exception text: on a
French Windows the message is *"Le certificat distant n'est pas valide"* and an English regex
would silently stop detecting the case.

On PS 5.1 the handshake fails while the body is being written (`GetRequestStream`), which runs
**before** `GetResponse`. PowerShell wraps that call in a `MethodInvocationException` — and,
unlike `GetResponse`, does not unwrap it for a `catch [System.Net.WebException]` clause — so the
whole exchange sits in one `try` whose `catch` walks the wrapper off before handing the real
exception to `ConvertTo-SEPMTransportError`. Guarding only `GetResponse` was the bug this hid:
every `POST`, authentication included, reported `SEPM.AuthenticationFailed` instead of
`SEPM.CertificateError`.

## Rejection of in-transport retry

`Invoke-SepmApiPaginated` retries a failed page once after a 1 s pause, then aborts the whole
read with a Transport Error naming the page. The retry deliberately lives in the **page loop,
not in `Invoke-SepmApi`**. Only paginated reads are `GET`s, which are idempotent. Retrying in the
transport would also retry `POST`s — `New-SEPMGroup`, `Send-SEPMCommand`,
`Add-SEPMFileFingerprintList` — where a slow-but-successful create would be applied twice.

## Considered options

- **Keep returning error strings, and add a documented prefix convention.** Rejected — this is
  the status quo that produced the null-token bug and the string sniffing. Any convention that
  relies on callers pattern-matching text will eventually be missed by a new caller.
- **Plain `throw "message"` with no `ErrorId`.** Rejected — `FullyQualifiedErrorId` would then
  be uncontrollable, so distinguishing "credential rejected" from "server down" would require
  matching the message text again, which is the trap being removed.
- **A dedicated `[SEPMApiException]` type.** Rejected as more surface than three ids justify;
  `ErrorId` plus `ErrorCategory` already gives callers what they need.
- **A fourth id for protocol violations** (a paginated response with no `lastPage`). Rejected —
  it maps to no distinct remedy, so it stays `SEPM.ApiError`.
- **Retry only transient `ErrorCategory` values.** Rejected in favour of retrying any failure
  once, for simplicity. The cost is one wasted round-trip on a deterministic failure.
- **Auto-detecting self-signed certificates and offering to bypass validation.** Out of scope
  here. Note that `$script:SkipCert` still has no public setter, so the certificate error reports
  the failure without telling the user how to resolve it.

## Consequences

- `Confirm-SEPMEventInfo` keeps its documented `System.Boolean` contract: it catches the
  Transport Error, writes a descriptive error, and returns `$false`. It is the one cmdlet whose
  job is "try this and tell me whether it worked".
- A paginated response missing `lastPage` is rejected rather than trusted. This is a
  **termination guard, not just validation**: `until ($resp.lastPage -eq $true)` can never
  become true for a payload with no `lastPage`, so trusting one spins the loop against the
  server forever. Removing the old `$resp -is [string]` check without adding this guard
  reintroduced exactly that hang.
- `Get-SEPMAccessToken` treats the token file as a cache (empty or unreadable → discard and
  re-authenticate) and the credential file as a secret (warn and treat as absent, so the
  existing prompt path handles it).
- `Get-SEPMAccessToken` throws when a response carries no token, instead of caching a null one.
- The seed scripts (`Seed-Fingerprints.ps1`, `Seed-HostGroups.ps1`) catch the DELETE failure
  rather than testing the response for an `Error:` prefix.
- The smoke harness `T` helper lost its `$result -like "Error:*"` branch; `-ExpectedError`
  matches thrown exceptions only, which it already supported.
- `Set-SEPMAuthentication` still persists credentials without verifying them against the server.
  A typo now fails loudly at first use rather than silently — but it is still written to disk
  unverified. Verifying before persisting is a deliberate follow-up, not an oversight.
