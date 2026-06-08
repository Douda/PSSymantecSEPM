# Excel export is a first-class module feature, not a consumer concern

Export-to-Excel cmdlets live in the module alongside API-calling cmdlets. They use
the `ImportExcel` module as a dependency. Consumers get formatted, multi-sheet XLSX
reports without running separate scripts or installing extra modules.

## Context

The module had one dead Export-ToExcel cmdlet (`Export-SEPMExceptionPolicyToExcel`)
from an early prototype. Real-world reporting (AXA firewall optimization project)
was done with ad-hoc consumer scripts: gather CLIXML on Windows, copy to Linux,
run a Dockerized script with `ImportExcel`. This worked but required the consumer
to own all formatting logic.

We chose to move the formatting logic into the module and ship real export cmdlets,
cementing `ImportExcel` as a permanent dependency.

## Considered Options

- **Keep Excel export consumer-side.** Consumers write their own scripts against
  the module's API output. Rejected — every consumer reinvents the same formatting
  logic. The module already knows the SEPM data model; it should format it.

- **Export to CSV/JSON only.** No external dependencies, but no multi-sheet
  formatting, no auto-sizing, no filtering affordances. Rejected — Excel is the
  lingua franca for firewall audit artifacts.

- **Make ImportExcel optional (dynamic load with `#Requires` guard).** Export cmdlets
  fail gracefully if the module isn't installed. Rejected — adds fragility. If a
  user installs PSSymantecSEPM, they get the export cmdlets working out of the box.

## Consequences

- `ImportExcel` is listed in `RequiredModules.psd1` and must be installed.
- New export cmdlets follow the pattern: accept a `Policy Snapshot` via pipeline
  OR fetch one internally. Three-sheet XLSX: Policies, FirewallRules,
  PolicyAssignments.
- Formatting helpers (`Format-ConnectionsDetails`, `Flatten-Hosts`, etc.) live in
  `Private/` — consumers who need custom reports pipe the snapshot to their own
  scripts, but the module provides polished defaults.
