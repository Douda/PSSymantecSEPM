# Collapse command dispatch behind a registry-driven Send-SEPMCommand

Seven public cmdlets duplicated the same command-dispatch pattern (session bootstrap,
target name→ID resolution, URI building, POST invocation). We consolidate them into a
single `Send-SEPMCommand` whose `-Type` parameter selects an entry from a lookup-table
registry. Adding a new SEPM command type is one registry entry plus one `[ValidateSet]`
member — no new parameter sets, no new files.

## Context

`Send-SEPMCommandActiveScan`, `Send-SEPMCommandFullScan`, `Send-SEPMCommandQuarantine`,
`Send-SEPMCommandGetFile`, `Send-SEPMCommandClearIronCache`, `Start-SEPScan`, and
`Update-SEPClientDefinitions` each duplicated:

- `begin { $session = Initialize-SEPMSession }`
- Name→ID resolution (10 copies: `Get-SEPComputers` / `Get-SEPMGroups` lookup, same
  loop in every file)
- URI construction (some used `Build-SEPMQueryURI`, others inlined `System.UriBuilder` —
  same logic, inconsistent style)
- `Invoke-SepmApi -Method POST -Uri $URI -Session $session`

Only the endpoint path, extra query/body parameters, and GroupName fan-out strategy
differed between cmdlets. `Start-SEPScan` and `Update-SEPClientDefinitions` expanded
groups into individual computers via per-computer POSTs; the other five passed `group_ids`
to the API for native fan-out. The API spec confirms `group_ids` is valid for all
endpoints — the expansion was a workaround, not a requirement.

## Considered options

- **DynamicParam** — would hide invalid params per `-Type`, giving clean
  `Get-Command -Syntax` output. Rejected: significantly more complex on PS 5.1,
  harder to test, and the module must support both PS 5.1 and PS 7+.
- **Per-command switch parameters** (e.g. `-ActiveScan`, `-FullScan`) — PowerShell
  enforces mutual exclusivity for free. Rejected: doesn't scale — adding a command
  type means adding a new switch, and the `process` block still needs a dispatch
  table. The `-Type` parameter makes the dispatch explicit.
- **Keep existing cmdlet names as thin wrappers** — backward-compatible. Rejected:
  the existing names are the surface that duplicated the logic; thin wrappers add
  an unnecessary indirection layer.

## Consequences

- Seven source files (`Send-SEPMCommand*.ps1`, `Start-SEPScan.ps1`,
  `Update-SEPClientDefinitions.ps1`) are deleted.
- A new `Send-SEPMCommand.ps1` is added.
- A new private helper `Resolve-SepmCommandTarget.ps1` extracts the name→ID
  resolution common to all command dispatch calls.
- GroupName fan-out is always API-native (`group_ids` query param). The
  `-PerComputer` expansion pattern is removed — it was redundant with the API's
  built-in group targeting.
- Validation for type-specific parameters (hash lengths, `[ValidateSet]` values)
  is driven from the registry table and enforced at runtime in `process`.
- The registry table includes stubs for unimplemented SEPM command types
  (`restart`, `eoc`) as commented-out entries, documenting the pattern for
  future additions.
- Seven test files are replaced by one test file mocking `Invoke-SepmApi` and
  exercising the dispatch through the registry.
- Seven smoke test scripts converge into one batch file per PS version.
