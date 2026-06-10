# Context

You are an autonomous coding agent working on **one standalone issue** (not linked to a PR).

- **Issue**: #{{ISSUE_NUMBER}} — {{ISSUE_TITLE}}

## Project context

Read `AGENTS.md` for project conventions: PowerShell 5.1/7+ module, ModuleBuilder build system, Pester tests, SEPM REST API wrappers. Coding standards are in `.sandcastle/CODING_STANDARDS.md`.

## Issue details

!`gh issue view {{ISSUE_NUMBER}} --json title,body,labels,comments`

## Parent PRD

If the issue body references a parent issue (look for "Parent", "PRD", or a linked issue), read that issue for the full specification.

# Task

Implement the requirements from the issue above.

## Workflow

1. **Read AGENTS.md** — understand the project's conventions before touching code.

2. **Load the tdd-ps skill** — read `.agents/skills/tdd-ps/SKILL.md` and follow its tracer-bullet workflow:
   - **Vertical slices only**: one test, one implementation, repeat. NEVER write all tests first.
   - **Tests verify behavior through public interfaces**, not implementation details.
   - **Always GREEN before refactoring**.
   - Follow PS 5.1/7+ compatibility rules from tdd-ps skill.

3. **Explore** — read the issue's agent brief carefully. Read the relevant source files and existing tests.

4. **Plan** — decide what to change. Keep the change as small as possible. Briefly state your plan, then proceed immediately. Do NOT ask for approval — this is an autonomous pipeline with no interactive user.

5. **Execute (TDD)**:
   - RED: write ONE failing test that describes expected behavior
   - GREEN: write minimal code to pass
   - REPEAT: one test → one impl at a time for each remaining behavior
   - REFACTOR: only when all tests are GREEN

6. **Verify (unit)** — run the full quality checks before committing:
   ```
   Build-ModuleLocal
   Invoke-Pester -Path ./Tests -Output Normal
   ```
   Fix ALL failures — not just those in your slice. Pre-existing test failures inherited from the base branch must be resolved.

7. **Verify (smoke)** — follow tdd-ps skill step 5 (Live Smoke Test):
   - **PS7**: deploy module, run `Scripts/Smoke/<CmdletName>/batch.ps7.ps1` locally
   - **PS5.1**: deploy smoke script with UTF-8 BOM to `/home/douda/Windows/`, run via `python3 Scripts/invoke-winrm.py`
   - Fix any real-API failures before committing. Smoke catches type mismatches, encoding bugs, and API shape changes that mocks miss.
   - PS5.1 smoke scripts MUST be written with UTF-8 BOM:
     ```bash
     pwsh -NoProfile -Command "
       \$bom = [System.Text.UTF8Encoding]::new(\$true)
       \$c = Get-Content ./Scripts/Smoke/<CmdletName>/batch.ps51.ps1 -Raw
       [System.IO.File]::WriteAllText('/home/douda/Windows/smoke-<cmdlet>.ps1', \$c, \$bom)
     "
     ```

8. **Commit** — a single git commit. Use conventional commit format:
   ```
   type(scope): description

   Closes #{{ISSUE_NUMBER}}
   ```
   Examples: `feat(auth): ...`, `fix(computers): ...`, `refactor(core): ...`

9. **Add a completion comment** — leave a brief comment on the issue confirming what was implemented:
   ```bash
   gh issue comment {{ISSUE_NUMBER}} --body "Implemented on branch \`sandcastle/issue-{{ISSUE_NUMBER}}\`. [describe key changes in 1-2 lines]"
   ```

10. **Do NOT close the issue** and do **NOT push**. All work stays local.

## Rules

- Work on **one issue per iteration**. Do not attempt multiple issues.
- Follow PS 5.1 compatibility: no `??`, no ternary operator, no `-SkipCertificateCheck` without version guard.
- UTF-8 with BOM for files that will run on the Windows VM.
- Forward slashes in all `Join-Path -ChildPath` calls.
- Do not leave commented-out code or TODO comments in committed code.
- If you are blocked (missing context, failing tests you cannot fix, external dependency), leave a comment on the issue and signal COMPLETE — do not close it.

# Done

When the issue is implemented, committed, and the completion comment is posted, output:

<promise>COMPLETE</promise>
