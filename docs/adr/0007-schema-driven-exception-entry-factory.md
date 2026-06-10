# Replace 16 Exception Rule factory methods with a schema-driven Build-ExceptionEntry

`SEPMPolicyExceptionsStructure` had 16 `Create*Hashtable` methods and 13 `Add*`
methods — each ~40–60 lines of the same pattern: build a hashtable, conditionally
add optional fields, construct a `rulestate` sub-object, validate mandatory params.
Adding a new Exception Rule type meant copy-pasting two methods. Fixing the
`rulestate` assembly meant editing 16 methods.

We replace all 29 methods with two (class-side `NewEntry`/`AddEntry`) plus a private
`Build-ExceptionEntry` function. The function is driven by a schema hashtable
(`$script:_ExceptionSchema`) that declares each type's API fields, required fields,
sub-objects (e.g. `processfile`, `signature_fingerprint`), and storage path in
`$this.configuration`.

`Build-ExceptionEntry` is tested directly (InModuleScope) under ADR-0002's third
criterion (complexity concentration): it absorbs behaviour previously spread across
16 methods, and testing it indirectly through `Update-SEPMExceptionPolicy` would
multiply test scaffolding for every validation edge case.

## Considered options

- **Builder pattern with fluent chaining** — a second class (`EntryBuilder`) with
  `.With()` methods. Rejected: adds a new API pattern when the existing caller
  already uses dispatch hashtables. PowerShell users think in hashtables; a fluent
  class fights the grain.

- **Internal collapse (keep methods, delegate to helper)** — each `Create*` method
  becomes a thin delegation to `_BuildEntry`. Rejected: keeps the interface shallow
  (29 methods remain); the real depth is in the implementation, not at the seam.

- **Keep as-is** — 16 methods, 900-line class. Rejected: no locality; every change
  to the `rulestate` pattern or validation logic touches 16 methods.

## Schema design decisions

- Sub-objects (e.g. `processfile`, `signature_fingerprint`) are passed as nested
  hashtables in the caller's `$Properties`, not as prefixed flat keys.
- `rulestate` defaults to `@{ source = 'PSSymantecSEPM' }`; callers can override
  by passing a `rulestate` key or merge via `rulestate_enabled`.
- Each type has an independent schema entry; shared field definitions are not
  extracted — 16 entries at ~200 lines total is small enough that indirection
  would cost more than duplication.
- Set-type entries (`extension_list`, `linux.extension_list`) silently replace on
  repeated calls within the same `AddEntry` lifetime.
