---
name: prd-to-pr
description: Scaffold a feature branch and tracking PR from a PRD issue and its sliced sub-issues. Use after to-issues to create the implementation PR with ordered checklist and branch. Creates branch with an empty commit, pushes, creates PR, then returns to dev.
---

# PRD to PR

Scaffold the implementation branch and tracking PR from a PRD issue and its sliced sub-issues (created by `to-issues`).

The issue tracker and triage label vocabulary should have been provided to you — run `/setup-matt-pocock-skills` if not.

## Process

### 1. Gather context

Identify these from the conversation context:

- **PRD issue**: the GitHub issue created by `to-prd` (number, title)
- **Sliced issues**: the issues created by `to-issues` (numbers, titles, dependencies)

If multiple PRD candidates exist, ask the user which one to scaffold.

If `to-issues` created zero sliced issues, **abort**. Tell the user: "No sliced issues found. The PRD may have been a single slice — scaffold manually if needed."

### 2. Edit the PRD issue body

Fetch the current PRD issue body. Append an `## Implementation Plan` section with an ordered checklist of sliced issues:

```md
## Implementation Plan

- [ ] #N — Title
- [ ] #N — Title
  - [ ] #N — Title (sub-task)
```

Order issues by dependency (blockers first, then siblings). Nest sub-tasks under their parent.

Update the issue body:

```bash
gh issue edit <PRD_NUMBER> --body "..."
```

### 3. Create the branch with an empty commit

Branch name: `{PRD_NUMBER}-{title-slug}` (lowercase, hyphens, no special chars).

Create the branch from `dev`, add an empty commit so the PR is immediately creatable, then switch back to `dev`:

```bash
git fetch origin dev
git checkout -b <branch-name> origin/dev
git commit --allow-empty -m "scaffold: PR for #{PRD_NUMBER} — {PRD_TITLE}"
git push -u origin <branch-name>
git checkout dev
```

This ensures the branch has a commit (required for PR creation) and returns the working directory to `dev`.

### 4. Create the PR

Create a regular PR to `dev` with a checklist body:

```bash
gh pr create --base dev --head <branch-name> \
  --title "feat: implement {PRD_TITLE}" \
  --body "$(cat <<'EOF'
## Summary
Implementation of #{PRD_NUMBER} — {PRD_TITLE}

## Implementation Plan
- [ ] #{N} — Title
- [ ] #{N} — Title
...

Closes #{PRD_NUMBER}
Closes #{N}
Closes #{N}
...
EOF
)"
```

Each sliced issue gets its own `Closes #N` line after the checklist. This ensures all related issues auto-close when the PR merges.

### 5. Output summary

Print:

- **Branch**: `<branch-name>`
- **PR URL**: link from `gh pr create` output
- **PRD issue**: `#N`
- **Sliced issues**: numbered list
