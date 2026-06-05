---
name: tdd-ps
description: Test-driven development for PowerShell modules with Pester. Red-green-refactor loop adapted for PS 5.1 and 7+. Use when building features or fixing bugs with TDD, writing Pester tests, or designing cmdlets for testability.
---

# Test-Driven Development for PowerShell

## Philosophy

**Core principle**: Tests should verify behavior through the module's public cmdlets, not through internal implementation details. The Private functions can change entirely; the tests shouldn't.

**Good tests** exercise public cmdlets with mocked system boundaries. They describe _what_ the module does for its users, not _how_ it does it internally. A good Pester test reads like a specification — "returns client status list with ONLINE and OFFLINE counts" tells you exactly what capability exists. These tests survive internal refactors because they don't care about which Private helper does the work.

**Bad tests** are coupled to implementation. They mock internal Private functions excessively, assert on call counts for functions the caller doesn't know about, or verify state through external means (reading config files directly instead of calling the cmdlet that produces the state). The warning sign: your test breaks when you refactor a Private function, but the cmdlet's output hasn't changed.

See [tests.md](tests.md) for Pester examples and [boundary-mocking.md](boundary-mocking.md) for the mocking spectrum.

## The PowerShell testing mindset

PowerShell modules differ from TypeScript/class-based code in ways that matter for TDD:

- **Module-scoped state is normal**: `$script:accessToken`, `$script:BaseURLv1`, `$script:SkipCert` — many cmdlets share state through module-scoped variables. Tests must manage this state explicitly inside `InModuleScope`.
- **Pester mocks commands, not objects**: `Mock Invoke-ABRestMethod { ... }` intercepts the command call itself. This means you can mock your own Private functions — and often should — but always mock at the right layer.
- **Build-before-test**: Modules built from split source (e.g., via ModuleBuilder) must be assembled into a `.psm1` before Pester can test them.
- **Two PS ecosystems**: PS 5.1 (Windows Server default) and PS 7+ (cross-platform). APIs like `-SkipCertificateCheck` don't exist in 5.1. Your tests may need version-aware mocking.

## Anti-Pattern: Horizontal Slices

**DO NOT write all tests first, then all implementation.** This is "horizontal slicing" — treating RED as "write all tests" and GREEN as "write all code."

This produces **crap tests**:

- Tests written in bulk test _imagined_ behavior, not _actual_ behavior
- You end up testing the _shape_ of things (data structures, parameter counts) rather than user-facing behavior
- Tests become insensitive to real changes — they pass when behavior breaks, fail when behavior is fine
- You outrun your headlights, committing to test structure before understanding the implementation

**Correct approach**: Vertical slices. One test → one implementation → repeat. Each test responds to what you learned from the previous cycle.

```
WRONG (horizontal):
  RED:   test1, test2, test3, test4, test5
  GREEN: impl1, impl2, impl3, impl4, impl5

RIGHT (vertical):
  RED→GREEN: test1→impl1
  RED→GREEN: test2→impl2
  RED→GREEN: test3→impl3
  ...
```

## Workflow

### 1. Planning

Before writing any code:

- **Read the project's CONTEXT.md** — use the domain glossary so test names, parameter names, and type names match the project's language. Don't invent new terms.
- **Identify the cmdlet's public interface**: verb-noun name, parameters, pipeline support, output type name.
- **Confirm with user** which behaviors to test (prioritize).
- **Identify the system boundary**: usually `Invoke-ABRestMethod` for API modules, or the equivalent HTTP/DB/filesystem call. This is your primary mock point.
- **Check for shared state**: does the cmdlet read `$script:` variables? Set them? Tests will need to manage that.
- **List the behaviors** (not implementation steps): "returns computers filtered by name", "paginates when more than one page exists", "outputs SEP.Computer type".
- **Get user approval on the plan**.

Ask: "What should the cmdlet's public interface look like? Which behaviors are most important to test?"

**You can't test everything.** Confirm which behaviors matter most. Focus on critical paths and complex logic, not every edge case.

### 2. Tracer Bullet

Write ONE test that confirms ONE thing about the system:

```
RED:   Write test for first behavior → test fails
GREEN: Write minimal cmdlet code to pass → test passes
```

This proves the path works end-to-end: Build-Module → Import → Pester → Mock → Cmdlet call → Assertion.

For a typical API-wrapper module, the tracer bullet looks like:

```powershell
Describe 'Get-MyData' {
    InModuleScope MyModule {
        BeforeAll {
            . ./Tests/Config/Common-Init.ps1
            . ./Tests/Config/Common-BeforeAll.ps1
            . ./Tests/Config/Common-TestEnvironmentSetup.ps1

            Mock Invoke-ABRestMethod -ModuleName MyModule {
                return [PSCustomObject]@{ Results = @('a', 'b') }
            }
        }

        It 'returns results from the API' {
            $result = Get-MyData
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 2
        }
    }
}
```

### 3. Incremental Loop

For each remaining behavior:

```
RED:   Write next test → fails
GREEN: Minimal code to pass → passes
```

Rules:

- One behavior at a time
- Only enough code to pass current test
- Don't add parameters the tests don't exercise yet (no `-ComputerName` until you have a test that uses it)
- Don't anticipate future tests
- Keep tests focused on observable behavior through the public cmdlet

### 4. Refactor

After all tests pass, look for refactor candidates (see [refactoring.md](refactoring.md)):

- [ ] Extract duplicated `begin` blocks (auth check, URI building)
- [ ] Deepen modules — move complexity behind simple cmdlet interfaces
- [ ] Consider: does shared `$script:` state need a dedicated getter/setter function?
- [ ] Run tests after each refactor step

**Never refactor while RED.** Get to GREEN first.

## Checklist Per Cycle

```
[ ] Test calls public cmdlet, not Private function (except pure utilities like URI builders)
[ ] Test asserts on output shape/type, not internal call counts (unless externally invisible: pagination, caching, retries)
[ ] Mock at the appropriate boundary layer (see boundary-mocking.md spectrum)
[ ] Test data comes from a DummyDataGenerator fixture (or equivalent), not inline blobs
[ ] TestDrive: used for any file I/O (config, tokens, credentials)
[ ] PS version differences handled (see ps-version-handling.md)
[ ] Code is minimal for this test — no speculative parameters or features
[ ] Domain terms from CONTEXT.md used in test names and variables
```
