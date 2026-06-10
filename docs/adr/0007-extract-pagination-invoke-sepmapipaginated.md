# Extract pagination into Invoke-SepmApiPaginated

`Get-SEPComputers`, `Get-SEPMGroups`, and `Get-SEPMCommandStatus` each duplicated the
same `do { pageIndex++; Build-SEPMQueryURI } until ($resp.lastPage)` loop. We extract
this into a single private module, `Invoke-SepmApiPaginated`, that wraps
`Invoke-SepmApi` with `-Uri`, `-PageSize`, `-AdditionalParams`, and `-Session`. Callers
no longer own `pageIndex`, `QueryStrings`, `Build-SEPMQueryURI`, or the loop control
flow — they call one function and get back the concatenated `$resp.content` across all
pages.

## Considered options

- **Absorb URI assembly into the module** (`-EndpointPath` instead of `-Uri`,
  module builds the full URL from `$session.BaseURLv1`). Rejected — merges two concerns
  (pagination control flow + URI construction). `Build-SEPMQueryURI` remains a separate
  concern that callers use for non-paginated calls and has its own test surface.
- **Registry-driven dispatch** (one cmdlet for all GETs). Rejected — complex callers
  like `Get-SEPComputers` have parameter-set logic that doesn't fit a generic registry.
  Candidate 1 from the architecture review (2026-06-10) may absorb `Invoke-SepmApiPaginated`
  as an implementation detail later, but the pagination extraction ships independently.

## Consequences

- `Invoke-SepmApiPaginated` is private, tested indirectly through its three callers
  per ADR-0002 (no PS-version branching, no module-scoped state).
- Three cmdlets lose their do/while loops; each gains a single function call.
- `Get-SEPMCommandStatus` no longer relies on `$null++` → 1 for uninitialized `pageIndex`.
