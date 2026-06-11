# Centralize API endpoint metadata in a declaratory registry

37 public cmdlets each construct URIs, query strings, and pagination loops by hand.
We introduce a declarative endpoint registry (`Get-SEPMApiEndpoint`) that maps each
cmdlet name to its API contract (path template with `{id}` placeholders, HTTP method,
query parameter → param name mapping, API version, pagination metadata, result unwrap
key). Two companion functions — `Resolve-SepmEndpoint` (URI/query/body assembly from
`$PSBoundParameters` + registry) and `Invoke-SepmEndpoint` (transport dispatch +
auto-pagination + result unwrapping) — form the single seam all callers cross.
Callers lose URI construction, `Build-SEPMQueryURI`, pagination loops, and result
unwrapping. They keep domain logic (parameter-set dispatch, name→ID pre-resolution,
post-filtering). Body construction splits into Tier 1 (flat, registry auto-builds)
and Tier 2 (complex — classes, scriptblocks — caller handles).

## Relationship to ADR-0006 and ADR-0007

ADR-0006 collapsed 7 command-dispatch cmdlets into a registry-driven
`Send-SEPMCommand`. That registry is internal to one function; this ADR generalises the
pattern across all 37 callers. `Send-SEPMCommand`'s internal `$commandRegistry` stays
as-is — it addresses type-specific validation and parameter dispatch, which are domain
concerns, not transport concerns.

ADR-0007 extracted pagination into `Invoke-SepmApiPaginated`. `Invoke-SepmEndpoint`
absorbs it — when `Paginated = $true` in the registry entry, the executor calls
`Invoke-SepmApiPaginated` internally. Callers never branch on pagination.
`Invoke-SepmApiPaginated`'s interface remains unchanged; it's now called from one
place instead of three.

## Why explicit $PSBoundParameters passing, not PSSEPCloud's implicit Get-Variable

PSSEPCloud's reference implementation uses `Get-Variable` to read function parameters
from the caller's scope, keyed by `$MyInvocation.MyCommand.Name`. We rejected this
for three reasons: `Get-Variable` leaks common parameters (`-Verbose`, `-ErrorAction`)
into the mapping unless explicitly filtered (a maintenance burden `Send-SEPMCommand`
already carries); `$MyInvocation.MyCommand.Name` silently breaks the registry lookup
on rename; and explicit `$PSBoundParameters` passing makes the data flow traceable
without understanding scope-based variable resolution. The current codebase already
uses `$PSBoundParameters` in `Send-SEPMCommand`, `Update-SEPMExceptionPolicy`, and
`Set-SepmConfiguration` — this is the house style.

## Considered options

- **PSSEPCloud's implicit approach** (Get-Variable, MyInvocation). Rejected — foreign
  to this codebase, requires common-parameter filtering, fragile on rename.
- **Registry handles all body construction.** Rejected — `Update-SEPMExceptionPolicy`'s
  class-based serialization and `Send-SEPMCommand`'s scriptblock-based body
  construction are domain logic, not transport. The Tier 1/Tier 2 split keeps the
  registry focused on transport concerns.
- **Per-endpoint .ps1 files.** Rejected — one hash table in one file is simpler to
  read, grep, and maintain. The file will be ~500 lines for 45+ endpoints; hash table
  syntax is verbose but this is a data file, not logic.
