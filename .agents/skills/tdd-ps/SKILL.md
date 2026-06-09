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

Before writing any code, gather requirements. How you do this depends on the starting point.

#### When given an issue reference (e.g., `tdd-ps #2`)

**The issue IS the spec.** Read it first and derive the plan from it. Do not re-ask questions it already answers.

1. **Fetch the issue**: `gh issue view #2 --json title,body,labels` — extract requirements, acceptance criteria, and any interface details.
2. **Produce a derived plan** — fill out every planning item from the issue content. If the issue says "add a Get-SEPMThreatStats cmdlet that returns threat stats," you now know the verb-noun name, the output shape, and the API boundary.
3. **Present concisely** — one summary paragraph + behavior list. Example: _"Issue #2 asks for Get-SEPMThreatStats. Public interface: Get-SEPMThreatStats [-SkipCertificateCheck], outputs SEP.ThreatStats. Two behaviors: returns stats with correct shape, enables cert skipping. Mocking Invoke-ABRestMethod at $BaseURLv1/stats/threat. Proceed?"_
4. **Only ask clarifying questions if the issue is genuinely ambiguous** — missing parameter details, unclear output shape, conflicting requirements. Otherwise, proceed directly to the tracer bullet after approval.
5. **Get brief approval** (one line is enough) and start the tracer bullet.

#### When called with no arguments

Auto-discover a PR on the current branch and work on the first unchecked slice from its `## Implementation Plan` checklist.

1. **Find the PR**: `git branch --show-current` → `gh pr list --head <branch> --state open --json number --jq '.[0].number'`.
   - Exactly 1 PR: proceed.
   - 0 PRs: error — "No open PR for branch X. Specify manually: `tdd-ps #N`."
   - >1 PR: error — "Multiple open PRs for branch X. Specify manually."
   - On `develop`/`main`: error (same as 0).
2. **Fetch PR body**: `gh pr view <N> --json body --jq '.body'`.
3. **Find `## Implementation Plan`** section. If missing: "No Implementation Plan in PR #N. Nothing to do."
4. **Find first `- [ ] #N`** line (not `[x]`, not indented, not a plain-text item).
   - Use word-boundary regex: `- \[ \] #<N>\b` scoped to the Implementation Plan section.
   - No unchecked items: "✅ PR #N: all slices complete." Exit.
5. **Fetch the slice issue**: `gh issue view #<N> --json title,body,labels`.
   - Open or closed: proceed (PR checkbox is truth).
   - 404: warn "Issue #N not found, skipping", check the box, return to step 4.
   - Empty title+body: stop and ask user.
6. **Proceed** as if `tdd-ps #N` was called (derive plan, get approval, etc.).

#### When working from conversation context (no issue)

No PR found on the current branch (or not on a feature branch). The user described the feature in chat. The requirements are in the conversation history, not an issue.

- **Read the project's CONTEXT.md** — use the domain glossary so test names, parameter names, and type names match the project's language. Don't invent new terms.
- **Identify the cmdlet's public interface**: verb-noun name, parameters, pipeline support, output type name.
- **Identify the system boundary**: usually `Invoke-ABRestMethod` for API modules, or the equivalent HTTP/DB/filesystem call. This is your primary mock point.
- **Check for shared state**: does the cmdlet read `$script:` variables? Set them? Tests will need to manage that.
- **Confirm with user** which behaviors to test (prioritize).
- **List the behaviors** (not implementation steps): "returns computers filtered by name", "paginates when more than one page exists", "outputs SEP.Computer type".
- **Get user approval on the plan** before writing any code.

Ask: "What should the cmdlet's public interface look like? Which behaviors are most important to test?"

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
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment

        InModuleScope PSSymantecSEPM {
            $script:configurationFilePath = Join-Path -Path 'TestDrive:' -ChildPath 'config.json'
            $script:credentialsFilePath   = Join-Path -Path 'TestDrive:' -ChildPath 'creds.xml'
            $script:accessTokenFilePath   = Join-Path -Path 'TestDrive:' -ChildPath 'token.xml'
        }
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'basic behavior' {
        BeforeAll {
            $fakeSession = New-TestSession
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM { return @{ data = @('a', 'b') } }
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

### 5. Live Smoke Test

After all unit tests pass and refactoring is clean, verify the cmdlet works against the live SEPM VM on both PS versions. This catches issues that unit tests with mocks miss: real API response shapes, PS5.1 type differences, encoding bugs, transport-layer problems.

**Run smoke at slice completion — not per cycle.** One smoke run after all red-green cycles are done and refactoring passes.

See [docs/agents/smoke-testing.md](../../../docs/agents/smoke-testing.md) for the full environment reference (credentials, ports, connectivity).

#### 5a. Create smoke scripts

Generate two scripts under `Scripts/Smoke/<CmdletName>/`:

```
Scripts/Smoke/<CmdletName>/
├── batch.ps7.ps1       # PS7 smoke
└── batch.ps51.ps1      # PS5.1 smoke
```

Both scripts start by dot-sourcing the shared init:

**PS7** — `batch.ps7.ps1`:
```powershell
$ErrorActionPreference = "Continue"
$RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
. "$RepoRoot/Scripts/Smoke/Common.ps1"

Write-Host "=== Smoke: <CmdletName> (PS7) ==="

# Use T helper (from Common.ps1) for GET cmdlets:
$results = @{}
$results.A1 = T "A1" "<label>" \`
    { <CmdletName> [-Param value] } \`
    { param($r) $r -ne $null -and ... }

# Or direct assertion for standalone scripts/mutation cmdlets
$result = <CmdletName> [-Param value]
if (-not $result) { throw "FAIL: no output" }
# ...
```

**PS5.1** — `batch.ps51.ps1`:
```powershell
$ErrorActionPreference = "Continue"
$RepoRoot = "C:\Users\smokeuser\Desktop\Shared"
. "$RepoRoot\Common-PS51.ps1"

Write-Host "=== Smoke: <CmdletName> (PS5.1) ==="
# ... same assertions as PS7, adapted for PS5.1 types ...
```

**PS5.1 files must have UTF-8 BOM** (`\xef\xbb\xbf` prefix). Write with:
```bash
pwsh -NoProfile -Command "
  \$bom = [System.Text.UTF8Encoding]::new(\$true)
  \$c = Get-Content ./Scripts/Smoke/<CmdletName>/batch.ps51.ps1 -Raw
  [System.IO.File]::WriteAllText('/home/douda/Windows/smoke-<cmdlet>.ps1', \$c, \$bom)
"
```

#### 5b. Deploy and run

```bash
# Deploy module to shared volume (PS5.1 needs it)
cp -r ./Output/PSSymantecSEPM /home/douda/Windows/PSSymantecSEPM

# Deploy Common-PS51.ps1 (once per VM session)
pwsh -NoProfile -c "
  \$bom = [System.Text.UTF8Encoding]::new(\$true)
  \$c = Get-Content ./Scripts/Smoke/Common-PS51.ps1 -Raw
  [System.IO.File]::WriteAllText('/home/douda/Windows/Common-PS51.ps1', \$c, \$bom)
"

# PS7: run locally
pwsh -NoProfile -File Scripts/Smoke/<CmdletName>/batch.ps7.ps1

# PS5.1: deploy script + run via WinRM (NTLM port 5985)
pwsh -NoProfile -c "
  \$bom = [System.Text.UTF8Encoding]::new(\$true)
  \$c = Get-Content ./Scripts/Smoke/<CmdletName>/batch.ps51.ps1 -Raw
  [System.IO.File]::WriteAllText('/home/douda/Windows/smoke-<cmdlet>.ps1', \$c, \$bom)
"
python3 Scripts/invoke-winrm.py 'C:\Users\smokeuser\Desktop\Shared\smoke-<cmdlet>.ps1'
```

#### 5c. Assertions

Smoke assertions differ from unit test assertions. They don't use Pester mocks — they hit real APIs.

**Required for every cmdlet:**
- Output is non-null/non-empty
- Output type is correct (check `GetType().FullName` or PSTypeName)
- Key fields are populated (not null/empty strings)

**For mutation cmdlets** (Add/Set/Remove), use the ground truth pattern: mutate → re-fetch via `Invoke-SepmApi` → assert the change persisted.

**For PS5.1**, watch for type differences:
- API output may be `Hashtable` instead of `PSCustomObject` (use `.$key` access)
- `ConvertFrom-Json` lacks `-AsHashtable` and `-Depth` (use `Invoke-SepmApi`)

#### 5d. On failure

1. **Check the API response directly**: `curl -sk ...` (see [docs/agents/smoke-testing.md](../../../docs/agents/smoke-testing.md) ground truth section)
2. **Compare PS7 vs PS5.1**: is the failure version-specific? Type mismatch? Encoding?
3. **Don't refactor the cmdlet to match smoke output** — fix the cmdlet, not the smoke
4. **If the cmdlet behavior is correct but smoke assertions are wrong**, update the smoke assertions

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

## Checklist Per Slice (after refactor, before declaring done)

```
[ ] All unit tests pass (Invoke-Pester green)
[ ] Smoke scripts created under Scripts/Smoke/<CmdletName>/
[ ] Smoke scripts dot-source Scripts/Smoke/Common.ps1 (PS7) or Common-PS51.ps1 (PS5.1)
[ ] Smoke passes on PS7 (pwsh -File .../batch.ps7.ps1)
[ ] Smoke passes on PS5.1 (WinRM via python3 Scripts/invoke-winrm.py)
[ ] No hardcoded credentials in smoke scripts (use Common.ps1 / Common-PS51.ps1)
[ ] PS5.1 smoke script deployed with UTF-8 BOM
```

### 6. Update PR Checklist

**Only when the slice came from a PR** (auto-discovery mode). Skip when called with an explicit issue reference.

After all checklist items above pass, check the box in the PR body:

```bash
# Read current body
BODY=$(gh pr view <PR_NUMBER> --json body --jq '.body')

# Replace first - [ ] #<ISSUE_NUMBER> with - [x] #<ISSUE_NUMBER>
# Scoped to the ## Implementation Plan section, word boundary on issue number
UPDATED=$(echo "$BODY" | ...)  # regex: match - [ ] #95\b, first occurrence after ## Implementation Plan

# Write via file to avoid shell escaping
gh pr edit <PR_NUMBER> --body-file <(echo "$UPDATED")
```

Then print summary (terse):

```
✅ Slice complete: #<N> — <title>
   PR #<PR>: <X>/<Y> slices done

   Next: #<NEXT> — <next title>
   Run `tdd-ps` to continue.
```

If all slices done: `🎉 All slices complete. PR #<PR> ready for review.`
