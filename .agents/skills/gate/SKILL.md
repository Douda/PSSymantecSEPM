---
name: gate
description: Pre-merge quality gate for PSSymantecSEPM PRs. Runs the full Pester test suite (PS 5.1 + PS 7) and live SEPM API smoke tests for every cmdlet touched by the branch diff. Use when the user invokes /gate or says "run the gate", "pre-merge check", "final check before merge".
---

# Gate — PSSymantecSEPM pre-merge validation

Runs the full test pyramid against the current branch, live against the SEPM VM.
Call after `/review` has passed — this is the last gate before merge.

Connection details, auth, and smoke run patterns: see `docs/agents/smoke-testing.md`.

## Workflow

### 1. Identify the branch

```bash
git branch --show-current
```

If on `main`, `master`, or `develop`, stop: "Gate runs on feature branches. Nothing to gate against."

### 2. Find impacted cmdlets

```bash
git diff develop...HEAD --stat -- Source/Public/
```

Extract each changed `.ps1` filename. Strip `.ps1` → cmdlet name. This is the
**impacted set** — these are the only cmdlets that need smoke tests.

Private functions (`Source/Private/`) are validated by Pester in steps 3–4.
No manual mapping needed — if Pester passes, private functions work.

### 3. Run Pester (PS 7 — local)

```bash
pwsh -NoProfile -c "Invoke-Pester -Path ./Tests -Output Normal"
```

Report pass/fail count. If failures: **stop here**. Do not proceed.

### 4. Run Pester (PS 5.1 — WinRM)

Deploy the built module, source, and test suite to the shared volume, then run Pester via WinRM.

**CRITICAL:** Always `rm -rf` targets first — `cp -r` into an existing directory nests
(e.g. `Tests/Tests/`), which breaks `Initialize-TestEnvironment`'s repo-root resolution
and makes `Build-Module` fail with "Source must point to a valid module."

```bash
# 1. Clean any stale deployments (prevents double-nesting)
rm -rf /home/douda/Windows/Tests /home/douda/Windows/PSSymantecSEPM /home/douda/Windows/Source

# 2. Deploy module, source (needed by Build-Module in TestHelpers), and tests
cp -r ./Output/PSSymantecSEPM /home/douda/Windows/PSSymantecSEPM
cp -r ./Source /home/douda/Windows/Source
cp -r ./Tests /home/douda/Windows/Tests

# 3. Write and deploy test runner with UTF-8 BOM
pwsh -NoProfile -c "
  `$bom = [System.Text.UTF8Encoding]::new(`$true)
  `$runner = @'
`$ErrorActionPreference = \"Continue\"
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { `$true }
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
Import-Module \"`$env:USERPROFILE\Desktop\Shared\PSSymantecSEPM\PSSymantecSEPM.psm1\" -Force
`$mod = Get-Module PSSymantecSEPM; & `$mod { `$script:SkipCert = `$true }
`$result = Invoke-Pester -Path \"`$env:USERPROFILE\Desktop\Shared\Tests\" -Output Normal -PassThru
if (`$result.FailedCount -gt 0) { Write-Host \"PESTER_FAILURES: `$(`$result.FailedCount)\"; exit 1 } else { Write-Host \"PESTER_PASS\"; exit 0 }
'@
  [System.IO.File]::WriteAllText('/home/douda/Windows/run-pester.ps1', `$runner, `$bom)
"

# 4. Run via WinRM
python3 Scripts/invoke-winrm.py 'C:\Users\smokeuser\Desktop\Shared\run-pester.ps1'
```

Pester is pre-installed on the VM. If failures: **stop here**. Do not proceed to smoke.

### 5. Run smoke tests for impacted cmdlets

For each cmdlet in the impacted set, look for a smoke suite:

```bash
ls Scripts/Smoke/<CmdletName>/batch.ps7.ps1 2>/dev/null && echo "FOUND" || echo "NOT_FOUND"
```

**Found** → run both PS versions:

```bash
# PS 7
pwsh -NoProfile -File Scripts/Smoke/<CmdletName>/batch.ps7.ps1

# PS 5.1 — deploy with BOM, then invoke via WinRM
pwsh -NoProfile -c "
  `$bom = [System.Text.UTF8Encoding]::new(`$true)
  `$c = Get-Content ./Scripts/Smoke/<CmdletName>/batch.ps51.ps1 -Raw
  [System.IO.File]::WriteAllText('/home/douda/Windows/smoke-<CmdletName>.ps1', `$c, `$bom)
"
python3 Scripts/invoke-winrm.py 'C:\Users\smokeuser\Desktop\Shared\smoke-<CmdletName>.ps1'
```

**Not found** → read `Scripts/Smoke/` directories to check if another suite
covers this cmdlet (some suites test multiple cmdlets, e.g. `Get-SEPSimpleGets1`
covers 6). If still no match, note: "No smoke suite for `<CmdletName>`."

Deduplicate: never run the same suite twice. Skip `Seed-*` directories
(data setup, not validation).

### 6. Summary

Table with three columns: Layer, PS 7, PS 5.1. Example:

| Layer | PS 7 | PS 5.1 |
|---|---|---|
| Pester | ✅ 234/234 passed | ✅ 231/231 passed |
| Smoke — Get-SEPComputers | — no suite | — no suite |
| Smoke — Update-SEPMExceptionPolicy | ✅ 35/35 PASS | ✅ 35/35 PASS |

Missing suites listed individually:

> "Smoke suites missing for: `Get-SEPComputers`, `Get-SEPMGroups`, `Get-SEPMVersion`"

End with: **"Gate passed. Ready to merge."** or **"Gate blocked — see failures above."**
