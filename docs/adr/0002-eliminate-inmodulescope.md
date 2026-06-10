# InModuleScope: test private functions indirectly except when PS-branching or module state forces direct access

Private functions are tested through the public cmdlets that call them, using
`Mock -ModuleName` to intercept module-internal dependencies. This keeps tests
focused on public behaviour and avoids coupling to implementation details.

Two narrow criteria grant an exception — a private function may use InModuleScope
for direct unit testing when:

1. **PS-version branching** — the function contains `$PSVersionTable.PSVersion.Major`
   checks that create distinct code paths for PS 5.1 vs PS 7+. Testing both
   branches through a public cmdlet would require complex mock scaffolding that
   obscures the actual test intent.

2. **Module-scoped state** — the function reads or writes `$script:` variables
   that don't exist outside the module. These can't be exercised at all without
   InModuleScope.

If neither criterion applies, test the function indirectly through its public
callers. When you need to verify a private function was called or control its
return value, use `Mock -FunctionName -ModuleName PSSymantecSEPM`.

Functions currently meeting these criteria:
- `Invoke-SepmApi` — PS-version branching (criteria 1)
- `Initialize-SEPMSession` — module-scoped state (criteria 2)
- `ConvertTo-SEPMJson` — PS-version branching (criteria 1)
- `Optimize-SEPMObject` — PS-version branching (criteria 1)
