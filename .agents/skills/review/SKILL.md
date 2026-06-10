---
name: review
description: Review the changes since a fixed point (commit, branch, tag, or merge-base) along two axes — Standards (does the code follow this repo's documented coding standards?) and Spec (does the code match what the originating issue/PRD asked for?). Runs both reviews in parallel sub-agents and reports them side by side. Use when the user wants to review a branch, a PR, work-in-progress changes, or asks to "review since X".
---

# Review

Two-axis review of the diff between `HEAD` and a fixed point the user supplies:

- **Standards** — does the code conform to this repo's documented coding standards?
- **Spec** — does the code faithfully implement the originating issue / PRD / spec?

Both axes run as **parallel sub-agents** so they don't pollute each other's context, then this skill aggregates their findings.

The issue tracker should have been provided to you — run `/setup-matt-pocock-skills` if `docs/agents/issue-tracker.md` is missing.

## Process

### 1. Pin the fixed point

Whatever the user said is the fixed point — a commit SHA, branch name, tag, `main`, `HEAD~5`, etc. Don't be opinionated; pass it through. If they didn't specify one, ask: "Review against what — a branch, a commit, or `main`?" Don't proceed until you have it.

Capture the diff command once: `git diff <fixed-point>...HEAD` (three-dot, so the comparison is against the merge-base). Also note the list of commits via `git log <fixed-point>..HEAD --oneline`.

### 2. Identify the spec source

Look for the originating spec, in this order:

1. Issue references in the commit messages (`#123`, `Closes #45`, GitLab `!67`, etc.) — fetch via the workflow in `docs/agents/issue-tracker.md`.
1. The PR body and comments (found via step 2b). A PR often restates the spec more richly than commit messages alone, and its checklist links to individual slice issues with acceptance criteria.
2. A path the user passed as an argument.
3. A PRD/spec file under `docs/`, `specs/`, or `.scratch/` matching the branch name or feature.
4. If nothing is found, ask the user where the spec is. If they say there isn't one, the **Spec** sub-agent will skip and report "no spec available".

### 2b. Identify the PR and sandcastle context

If the review target is a branch (not a bare commit), find the associated PR and
its sandcastle execution artifacts. The sandcastle loop (`.sandcastle/main.mts`)
drives slice-by-slice implementation: implementer → reviewer → merge → PR
checklist update.

**Find the PR:**

```bash
gh pr list --head <branch> --json number,title,body,comments
```

If no PR is found, skip this step — the branch may be local-only.

**From the PR body, find all slices** (checked and unchecked). The PR body uses
a checklist convention `- [x] #NNN — Title` for completed slices and
`- [ ] #NNN — Title` for pending ones. Extract every `#NNN` reference.

**Find sandcastle logs** by matching the PR branch name:

```bash
ls .sandcastle/logs/sandcastle-<pr-branch>-slice-*-{implementer,reviewer}.log
```

For each slice, two logs may exist:
- `*-implementer.log` — always present if the slice was attempted.
- `*-reviewer.log` — present only if the implementer produced commits. A
  missing reviewer log with a present implementer log means the implementer
  aborted with zero commits (reviewer was skipped by design).

**Find stale sandcastle branches and worktrees:**

```bash
git branch --list "sandcastle/<pr-branch>/slice-*"
git worktree list | grep "sandcastle/<pr-branch>"
```

Sandcastle creates sandbox worktrees at
`.sandcastle/.sandboxes/sandcastle-<pr-branch>-slice-<num>_sandbox/` — these
are closed after successful merge. Stale ones indicate a crash mid-execution.
Merge worktrees at `.sandcastle/worktrees/mrg-<pr-branch>` are cleaned after
each round; their presence means sandcastle crashed during merge.

**For each sandcastle log read:**
- Did the implementer finish with `<promise>COMPLETE</promise>`? What was built?
  Did all tests pass?
- Was a reviewer run? Did it make improvements? Were they committed?
- If the implementer log is truncated (no `<promise>COMPLETE</promise>`), the
  agent crashed or was interrupted mid-execution — note this as ❌ aborted.

**Cross-check PR checklist against sandcastle logs.** A slice marked `[x]` in
the PR body should have both implementer and reviewer logs (or at least an
implementer log showing COMPLETE). A slice marked `[x]` with a truncated
implementer log and no reviewer means the checklist is wrong — someone
manually checked the box without sandcastle completing.

### 3. Identify the standards sources

Anything in the repo that documents how code should be written. Common locations:

- `CLAUDE.md`, `AGENTS.md`
- `CONTRIBUTING.md`
- `CONTEXT.md`, `CONTEXT-MAP.md`, per-context `CONTEXT.md` files
- `docs/adr/` (architectural decisions are standards)
- `.editorconfig`, `eslint.config.*`, `biome.json`, `prettier.config.*`, `tsconfig.json` (machine-enforced standards — note them but don't re-check what tooling already checks)
- Any `STYLE.md`, `STANDARDS.md`, `STYLEGUIDE.md`, or similar at the repo root or under `docs/`

Collect the list of files. The **Standards** sub-agent will read them.

### 4. Spawn both sub-agents in parallel

Send a single message with two `Agent` tool calls. Use the `general-purpose` subagent for both.

**Standards sub-agent prompt** — include:

- The full diff command and commit list.
- The list of standards-source files you found in step 3.
- The brief: "Read the standards docs. Then read the diff. Report — per file/hunk where relevant — every place the diff violates a documented standard. Cite the standard (file + the rule). Distinguish hard violations from judgement calls. Skip anything tooling enforces. Under 400 words."

**Spec sub-agent prompt** — include:

- The diff command and commit list.
- The path or fetched contents of the spec.
- The brief: "Read the spec. Then read the diff. Report: (a) requirements the spec asked for that are missing or partial; (b) behaviour in the diff that wasn't asked for (scope creep); (c) requirements that look implemented but where the implementation looks wrong. Quote the spec line for each finding. Under 400 words."

If the spec is missing, skip the Spec sub-agent and note this in the final report.

### 5. Aggregate

Present three sections:

#### Standards + Spec

Present the two sub-agent reports under `## Standards` and `## Spec` headings,
verbatim or lightly cleaned. Do **not** merge or rerank findings — the two axes
are deliberately separate so the user can see them independently.

#### Sandcastle

For each slice referenced in the PR, report its sandcastle execution status:

- **✅ Complete** — implementer COMPLETE + reviewer COMPLETE.
- **❌ Aborted** — implementer log truncated, no `<promise>COMPLETE</promise>`.
- **⚠️ Missing reviewer** — implementer COMPLETE, but no reviewer log exists.
  This should not happen under normal sandcastle operation (reviewer always
  runs after a successful implementer); it means sandcastle crashed between
  implement and review phases.
- **— Not run** — no sandcastle log exists for this slice.

Format as a table:

```
| Slice | Implementer | Reviewer | Notes |
|---|---|---|---|
| #138 — Build-ExceptionEntry | ✅ 732 tests | ✅ helpers extracted | Merged into branch |
| #139 — Wire into class | — not run | — | No sandcastle log |
| #140 — Smoke + cleanup | ❌ 9-line log | ⚠️ missing | Agent crashed before work |
```

If stale sandcastle branches or worktrees exist, add a subsection:

```
### Stale artifacts
- `sandcastle/<pr-branch>/slice-<N>` — branch alive, sandbox worktree not cleaned up
```

If no PR or sandcastle context exists (no PR found, or target is a bare commit),
replace the section with: "_No PR or sandcastle context found for this branch._"

#### Summary

End with a one-line summary: total findings per axis, and the worst single
issue (if any) flagged.

## Why two axes

A change can pass one axis and fail the other:

- Code that follows every standard but implements the wrong thing → **Standards pass, Spec fail.**
- Code that does exactly what the issue asked but breaks the project's conventions → **Spec pass, Standards fail.**

Reporting them separately stops one axis from masking the other.
