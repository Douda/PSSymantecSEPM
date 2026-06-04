---
name: sandcastle-cleanup
description: Clean up stale sandcastle git branches and worktrees after AI-run issue implementations. Use when user wants to delete sandcastle branches, clean up worktrees, or mentions stale sandcastle branches.
---

# Sandcastle Cleanup

## Quick start

```bash
bash .agents/skills/sandcastle-cleanup/scripts/cleanup.sh
```

Safe by default — dry-runs first. Pass `--force` to actually delete.

## What it does

1. Finds all `sandcastle/*` branches (`git branch --list 'sandcastle/*'`)
2. For each, locates the associated git worktree path
3. If a worktree exists: checks for uncommitted changes; skips if dirty
4. Removes worktree (`git worktree remove --force`), then deletes branch (`git branch -D`)
5. Branches without worktrees are deleted directly

## Usage

```bash
# Dry-run (safe, shows what would be deleted)
bash .agents/skills/sandcastle-cleanup/scripts/cleanup.sh

# Actually delete
bash .agents/skills/sandcastle-cleanup/scripts/cleanup.sh --force
```
