# Pester Smoke Parity Plan

Branch: `54-pester-smoke-parity` (off `47-comprehensive-smoke-tests-update-sepmexceptionpolicy`)

Goal: Replicate the 35 live smoke test assertions from `smoke-batch-ps7.ps1` / `smoke-ps51.ps1`
inside the Pester test suite so these checks run in CI without a live SEPM instance.

## Current state

`Tests/Update-SEPMExceptionPolicy.Tests.ps1` has ~25 tests across 6 Contexts (A–F).
They mock `Invoke-ABRestMethod` and assert on the PATCH body via `$params.Body | ConvertFrom-Json`.

| Context | Tests | Smoke parity |
|---------|-------|-------------|
| Default | 6 | ✅ A1–A5 + cross-param-set combo |
| WindowsFile | 5 | ⚠️ B1, B10, cross-params only — missing 8 |
| WindowsFolder | 6 | ✅ C1–C6 |
| WindowsExtension | 6 | ✅ D1–D5 + explicit ScanType |
| Tamper | 4 | ⚠️ E1, E3, validation — missing E2 |
| MacFile | 4 | ⚠️ F1, F3, validation — missing F2 |
| Errors | 0 | ❌ Missing G3 |

## Blocking dependency

**PR #54 must merge first.** `Update-SEPMExceptionPolicy` currently calls `Invoke-SepmApi`
directly for the PATCH (not `Invoke-ABRestMethod`). The existing tests mock the wrong function.

## Phase 1: Mock migration (Invoke-ABRestMethod → Invoke-SepmApi)

**What changes**: Every `Mock Invoke-ABRestMethod` → `Mock Invoke-SepmApi`, and every
`Should -Invoke Invoke-ABRestMethod -ParameterFilter { ($params.Body | ConvertFrom-Json)... }`
→ `Should -Invoke Invoke-SepmApi -ParameterFilter { $Body -match '...' }`.

**Why `$Body -match` instead of `ConvertFrom-Json`**: On PS7, `Invoke-SepmApi` receives
`-Body $bodyJson` as a named string parameter (already serialized JSON). We can't
`ConvertFrom-Json` inside a `ParameterFilter` because it runs in a constrained scope.
String matching (`-match`) is the portable alternative.

**Example migration**:

```powershell
# Before
Mock Invoke-ABRestMethod -ModuleName PSSymantecSEPM {
    return [PSCustomObject]@{ status = 'success' }
}
Should -Invoke Invoke-ABRestMethod -ModuleName PSSymantecSEPM -ParameterFilter {
    $body = $params.Body | ConvertFrom-Json
    $body.enabled -eq $true
} -Exactly 1 -Scope It

# After
Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
    return [PSCustomObject]@{ status = 'success' }
}
Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter {
    $Method -eq 'PATCH' -and $Body -match '"enabled":true'
} -Exactly 1 -Scope It
```

**Risk**: `-match` on JSON strings is fragile (whitespace, key ordering). Mitigation:
use `-match` patterns that are specific enough to avoid false positives but loose
enough to survive serialization differences. E.g., `'"sonar":true'` instead of
assuming `"sonar"` comes before `"securityrisk"`.

**Scope**: 25 existing tests touched. Do this as one commit, run full suite.

## Phase 2: Fill coverage gaps (10 new tests)

Tests to add, organized by Context:

### WindowsFile (`Context 'WindowsFile'`)

| # | Test name | Action | Assertion (`$Body -match`) |
|---|-----------|--------|---------------------------|
| B2 | explicit AllScans | `-Path ... -AllScans` | `'"sonar":true'` AND `'"securityrisk":true'` AND `'"applicationcontrol":true'` AND `'"scancategory":"AllScans"'` |
| B3 | Sonar only | `-Path ... -Sonar` | `'"sonar":true'` AND NOT `'"securityrisk":true'` |
| B4 | SecurityRisk AutoProtect | `-Path ... -SecurityRiskCategory AutoProtect` | `'"securityrisk":true'` AND `'"scancategory":"AutoProtect"'` AND NOT `'"sonar":true'` |
| B5 | ApplicationControl only | `-Path ... -ApplicationControl` | `'"applicationcontrol":true'` AND NOT `'"sonar":true'` |
| B6 | AC + ExcludeChildProcesses | `-Path ... -ApplicationControl -ExcludeChildProcesses` | `'"applicationcontrol":true'` AND `'"recursive":true'` |
| B7 | Sonar + AppCtrl | `-Path ... -Sonar -ApplicationControl` | `'"sonar":true'` AND `'"applicationcontrol":true'` AND NOT `'"securityrisk":true'` |
| B8 | Sonar + SecurityRisk | `-Path ... -Sonar -SecurityRiskCategory ScheduledAndOndemand` | `'"sonar":true'` AND `'"securityrisk":true'` AND `'"scancategory":"ScheduledAndOndemand"'` |
| B9 | PathVariable [SYSTEM] | `-Path C:\Windows\file.exe -PathVariable '[SYSTEM]'` | `'"pathvariable":"[SYSTEM]"'` |
| B13 | File + PolicyDescription | `-Path ... -AllScans -PolicyDescription "desc"` | `'"desc":"desc"'` AND `'"sonar":true'` |

**Note on negatives**: `NOT '"securityrisk":true'` means the body should NOT contain that
string. Verify with `$Body -notmatch '"securityrisk":true'`.

### Tamper

| # | Test name | Action | Assertion |
|---|-----------|--------|-----------|
| E2 | PathVariable [SYSTEM] | `-TamperPath ... -PathVariable '[SYSTEM]'` | `'"pathvariable":"[SYSTEM]"'` in tamper_files |

### MacFile

| # | Test name | Action | Assertion |
|---|-----------|--------|-----------|
| F2 | MacPathVariable [HOME] | `-MacPath ... -MacPathVariable '[HOME]'` | `'"pathvariable":"[HOME]"'` in mac.files |

### Errors (new Context)

| # | Test name | Action | Assertion |
|---|-----------|--------|-----------|
| G3 | NonExistentPolicy | `-PolicyName "BadName" -EnablePolicy` | `Should -Throw -ExpectedMessage "*not found*"` |

## Phase 3: PS5.1 body serialization (out of scope for now)

Pester tests run on PS7 in CI. On PS5.1, the body is serialized via `ConvertTo-JsonSafe`
(a custom StringBuilder-based serializer), which produces different whitespace from PS7's
`ConvertTo-Json -Compress`. String `-match` assertions should survive this because they
look for substrings like `"sonar":true`, not exact formatting.

However, if we add PS5.1 CI for Pester, we'd need to verify the body assertions hold.
Decision: defer to a follow-up issue; focus on PS7 CI first.

## Execution order

```
1. Phase 1: Mock migration (one commit, full suite must stay green)
   - Replace Mock Invoke-ABRestMethod → Mock Invoke-SepmApi in all 6 contexts
   - Replace ParameterFilter assertions ($params.Body | ConvertFrom-Json → $Body -match)
   - Run: Invoke-Pester Tests/Update-SEPMExceptionPolicy.Tests.ps1

2. Phase 2: Fill gaps (one commit per context group, or all-in-one)
   - Add B2-B9, B13 to WindowsFile context
   - Add E2 to Tamper context
   - Add F2 to MacFile context
   - Add Errors context with G3
   - Run: Invoke-Pester Tests/Update-SEPMExceptionPolicy.Tests.ps1

3. Final: Full suite green → 35 smoke-parity Pester tests (+ existing extras)
```

## Risks

| Risk | Mitigation |
|------|-----------|
| `$Body -match` false negatives (whitespace diff) | Use relaxed patterns: `'"key":value'` not `'"key" : value'` |
| `$Body -match` false positives (key in wrong object) | Include context: match `'"pathvariable":"[SYSTEM]"'` only when testing PathVariable, not generic |
| `Invoke-SepmApi` receives different param names than `Invoke-ABRestMethod` | ParameterFilter uses `$Method`, `$Body`, `$Uri` — all present in Invoke-SepmApi signature |
| `Get-SEPMExceptionPolicy` mock needed for WindowsExtension context | Already mocked; no change needed (it's a separate function from Invoke-SepmApi) |
| PS5.1 `ConvertTo-JsonSafe` output differs from PS7 | Phase 3 follow-up; `-match` patterns should survive both formats |

## Estimated scope

- **Phase 1**: ~25 tests touched (migration), ~1h
- **Phase 2**: ~10 tests added, ~30min
- **Phase 3**: Deferred

Total: ~2 commits, no source changes, test-only.
