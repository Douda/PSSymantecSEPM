#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=true
if [[ "${1:-}" == "--force" ]]; then
  DRY_RUN=false
fi

BRANCHES=$(git branch --list 'sandcastle/*' | sed 's/^[* ]*//')

if [[ -z "$BRANCHES" ]]; then
  echo "No sandcastle branches found."
  exit 0
fi

echo "Found sandcastle branches:"
echo "$BRANCHES" | sed 's/^/  /'
echo ""

DELETED=0
SKIPPED=0

while IFS= read -r branch; do
  [[ -z "$branch" ]] && continue

  # Find worktree path for this branch
  WORKTREE=$(git worktree list --porcelain | awk -v br="$branch" '
    /^worktree /{path=$2}
    /^branch / && $2=="refs/heads/'"$branch"'" {print path}
  ')

  if [[ -n "$WORKTREE" ]]; then
    # Check for uncommitted changes in the worktree
    if git -C "$WORKTREE" diff --quiet && git -C "$WORKTREE" diff --cached --quiet; then
      if $DRY_RUN; then
        echo "[DRY-RUN] Would remove worktree + branch: $WORKTREE"
      else
        git worktree remove --force "$WORKTREE"
        echo "Removed worktree + branch: $WORKTREE"
      fi
      DELETED=$((DELETED + 1))
    else
      echo "SKIP $branch — worktree has uncommitted changes (may be in-progress)"
      SKIPPED=$((SKIPPED + 1))
    fi
  else
    if $DRY_RUN; then
      echo "[DRY-RUN] Would delete branch (no worktree): $branch"
    else
      git branch -D "$branch"
      echo "Deleted branch (no worktree): $branch"
    fi
    DELETED=$((DELETED + 1))
  fi
done <<< "$BRANCHES"

echo ""
if $DRY_RUN; then
  echo "DRY-RUN complete. Would delete $DELETED branch(es)."
  echo "Run with --force to execute."
else
  echo "Done. Deleted $DELETED branch(es)."
fi
if [[ $SKIPPED -gt 0 ]]; then
  echo "Skipped $SKIPPED branch(es) with uncommitted changes."
fi
