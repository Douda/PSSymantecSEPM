# Deepen exception policy serialization with ConvertTo-SEPMJson and Optimize-SEPMObject

`Update-SEPMExceptionPolicy` had two complete JSON serialization paths (PS 7+
`ConvertTo-Json -Depth 100` vs. PS 5.1 manual `ConvertTo-JsonSafe`) and duplicate
empty-property stripping logic (PS 7+ `Optimize-ExceptionPolicyStructure` vs. PS 5.1
inline IDictionary/IList walk). We extracted two private modules
(`ConvertTo-SEPMJson` and `Optimize-SEPMObject`) that hide PS version branching
behind a single seam. PS version branching is tested via InModuleScope (ADR-0002
exception), same as `Invoke-SepmApi`. All other `ConvertTo-Json` call sites in the
module now route through `ConvertTo-SEPMJson` to eliminate latent PS 5.1 depth-2
truncation bugs.

## Considered Options

- **Single `ConvertTo-SEPMBody` that both strips empties and serializes.** Rejected —
  the empty-stripping rules are SEPM domain knowledge (mac.linux, extension_list, 
  lockedoptions), while serialization is transport knowledge. Separating them means
  `Optimize-SEPMObject` can evolve with the SEPM API schema and
  `ConvertTo-SEPMJson` can evolve with PS version requirements independently.
- **Keep `[object]` on `$this.configuration` in the class.** Rejected — the `[object]`
  type existed only to work around PS 5.1's depth-2 truncation. With
  `ConvertTo-SEPMJson` handling safe serialization, `[hashtable]` behaves identically
  on both PS versions and eliminates the IDictionary/IList inspection branch.
- **Keep `ConvertTo-SEPMJson` scoped to exception policy only.** Rejected — every
  `ConvertTo-Json` call in the module is a latent depth-2 bug on PS 5.1. Absorbing
  all call sites now prevents future issues when a body inevitably goes deeper than
  two levels.

## Consequences

- `Optimize-ExceptionPolicyStructure.ps1` is deleted (absorbed into `Optimize-SEPMObject`).
- The embedded `ConvertTo-JsonSafe` function in `Update-SEPMExceptionPolicy` is deleted
  (extracted to `ConvertTo-SEPMJson`).
- `00_Exceptions-Policy.ps1`: `$this.configuration` type changes from `[object]` to
  `[hashtable]`. Method signatures that referenced the wrapper behavior are simplified.
- Seven call sites across `Move-SEPClientGroup`, `Send-SEPMCommandClearIronCache`,
  `Add-SEPMFileFingerprintList`, `New-SEPMGroup`, `Remove-SEPMGroup`,
  `Update-SEPMFileFingerprintList` switch to `ConvertTo-SEPMJson`.
