# Eliminate InModuleScope; test private functions through public cmdlet interface

Pester 5's guidance is to avoid `InModuleScope` — it prevents proper testing of
published functions, slows Discovery, and couples tests to module internals.
We're eliminating it entirely: private functions are tested through the public
cmdlets that call them, using `-ModuleName` on Mock to intercept module-internal
calls. Three exceptions retain InModuleScope: `Invoke-SepmApi` (transport layer with
PS-version branching, certificate-bypass logic, and return-type coercion),
`Initialize-SEPMSession` (auth bootstrap that manipulates module-scoped state and
calls `Test-SEPMAccessToken`), and `TestHelpers` (test infrastructure lifecycle —
`Initialize-TestEnvironment`/`Clear-TestEnvironment` — used for setup and teardown,
not test assertions).

## Considered alternatives

- **Move InModuleScope inside It blocks for all private functions.** Rejected — this
  still couples tests to module internals and contradicts the Pester 5 guidance.
- **Promote private functions to public to test them directly.** Rejected — most
  private functions have no standalone value to end users (e.g., `Build-SEPMQueryURI`
  is an implementation detail of the URL construction).
