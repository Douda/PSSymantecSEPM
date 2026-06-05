# Context

You are an autonomous coding agent working on **one pre-selected vertical slice**.

- **PR**: #{{PR_NUMBER}} on branch `{{PR_BRANCH}}`
- **Slice**: #{{ISSUE_NUMBER}} — {{ISSUE_TITLE}}

## Project context

Read `AGENTS.md` for project conventions: PowerShell 5.1/7+ module, ModuleBuilder build system, Pester tests, SEPM REST API wrappers. Coding standards are in `.sandcastle/CODING_STANDARDS.md`.

## Issue details

!`gh issue view {{ISSUE_NUMBER}} --json title,body,labels,comments`

## Parent PRD

If the issue body references a parent PRD issue (look for "Parent", "PRD", or a linked issue), read that issue for the full specification.

# Task

Implement **one vertical slice** from the issue above. This slice is a tracer bullet — a thin, complete path through all integration layers.

## Workflow

1. **Read AGENTS.md** — understand the project's conventions before touching code.

2. **Load the tdd-ps skill** — read `.agents/skills/tdd-ps/SKILL.md` and follow its tracer-bullet workflow:
   - **Vertical slices only**: one test, one implementation, repeat. NEVER write all tests first.
   - **Tests verify behavior through public interfaces**, not implementation details.
   - **Always GREEN before refactoring**.
   - Follow PS 5.1/7+ compatibility rules from tdd-ps skill.

3. **Explore** — read the issue's agent brief carefully. Read the relevant source files and existing tests.

4. **Plan** — decide what to change. Keep the change as small as possible. Present your plan before coding.

5. **Execute (TDD)**:
   - RED: write ONE failing test that describes expected behavior
   - GREEN: write minimal code to pass
   - REPEAT: one test → one impl at a time for each remaining behavior
   - REFACTOR: only when all tests are GREEN

6. **Verify** — run the full quality checks before committing:
   ```
   Build-ModuleLocal
   Invoke-Pester -Path ./Tests -Output Detailed
   ```
   Fix ALL failures — not just those in your slice. Pre-existing test failures inherited from the base branch must be resolved.

7. **Commit** — a single git commit. Use conventional commit format:
   ```
   type(scope): description

   Closes #{{ISSUE_NUMBER}}
   ```
   Examples: `feat(auth): ...`, `fix(computers): ...`, `refactor(core): ...`

8. **Verify PR is still open** — before updating the checklist, confirm the PR hasn't been merged:
   ```bash
   gh pr view {{PR_NUMBER}} --json state --jq '.state'
   ```
   If the output is `MERGED`, the PR was closed mid-run. Do NOT update the checklist — instead, warn in the commit message that the PR was merged prematurely and signal COMPLETE.

9. **Update PR checklist** — mark this slice as done in the PR description:
   ```bash
   gh pr view {{PR_NUMBER}} --json body --jq '.body' > /tmp/pr-body.md
   sed -i 's/- \[ \] #{{ISSUE_NUMBER}} /- [x] #{{ISSUE_NUMBER}} /' /tmp/pr-body.md
   gh pr edit {{PR_NUMBER}} --body-file /tmp/pr-body.md
   ```

10. **Do NOT close the issue** and do **NOT push**. All work stays local.

## Rules

- Work on **one slice per iteration**. Do not attempt multiple issues.
- Follow PS 5.1 compatibility: no `??`, no ternary operator, no `-SkipCertificateCheck` without version guard.
- UTF-8 with BOM for files that will run on the Windows VM.
- Forward slashes in all `Join-Path -ChildPath` calls.
- Do not leave commented-out code or TODO comments in committed code.
- If you are blocked (missing context, failing tests you cannot fix, external dependency), leave a comment on the issue and signal COMPLETE — do not close it.

# Done

When the slice is implemented, committed, and the PR checklist is updated, output:

<promise>COMPLETE</promise>
