// Sequential Reviewer — implement-then-review loop (PR + standalone issues)
//
// Priority 1a — In-progress PRs (at least one checked `- [x]` slice): finish
//              what was started — picks the one with most remaining slices.
// Priority 1b — Fresh PRs (no checked slices): picks the one with most
//              unchecked slices.
// Within a PR: implements slices in checklist order, reviews, merges back.
//
// Priority 2 — Standalone issues: if no PR slices remain, picks up standalone
//              ready-for-agent issues not referenced in any PR, branches off
//              develop, implements, reviews, and merges to develop.
//
// Usage:
//   npx tsx .sandcastle/main.mts
// Or add to package.json:
//   "scripts": { "sandcastle": "npx tsx .sandcastle/main.mts" }

import * as sandcastle from "@ai-hero/sandcastle";
import { docker } from "@ai-hero/sandcastle/sandboxes/docker";
import { execSync } from "child_process";

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

// Maximum number of implement→review cycles to run before stopping.
const MAX_ITERATIONS = 10;

// Hooks run inside the sandbox before the agent starts each iteration.
const hooks = {
  sandbox: { onSandboxReady: [
    { command: "pwsh -NoProfile -Command Build-ModuleLocal" },
  ] },
};

// Copy node_modules from the host into the worktree (harmless for PowerShell projects).
const copyToWorktree = ["node_modules"];

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

function sh(cmd: string): string {
  try {
    return execSync(cmd, { encoding: "utf-8", stdio: ["ignore", "pipe", "ignore"] }).trim();
  } catch {
    return "";
  }
}

/** Like sh() but returns {ok, out} — ok=false means the command failed (non-zero exit). */
function shCheck(cmd: string): { ok: boolean; out: string } {
  try {
    const out = execSync(cmd, {
      encoding: "utf-8",
      stdio: ["ignore", "pipe", "pipe"],
    }).trim();
    return { ok: true, out };
  } catch (e: any) {
    return { ok: false, out: e?.stderr?.toString().trim() || e?.message || "unknown error" };
  }
}

/**
 * Get all issue numbers referenced in any open PR body.
 * Used to exclude PR-linked issues from standalone discovery.
 */
function getIssuesInPRs(): Set<number> {
  const prsJson = sh('gh pr list --state open --json body --limit 30');
  const nums = new Set<number>();
  if (!prsJson) return nums;

  try {
    const prs = JSON.parse(prsJson) as { body: string }[];
    for (const pr of prs) {
      for (const m of pr.body.matchAll(/#(\d+)/g)) {
        nums.add(parseInt(m[1], 10));
      }
    }
  } catch {}
  return nums;
}

// ---------------------------------------------------------------------------
// PR-slice discovery (priority 1)
// ---------------------------------------------------------------------------

interface Slice {
  num: number;
  title: string;
}

interface DiscoveredSlice {
  prNumber: number;
  prBranch: string;
  issueNumber: number;
  issueTitle: string;
}

/**
 * Find an open PR with unchecked ready-for-agent slices to work on.
 * Two-pass priority:
 *   1. In-progress PRs (at least one checked `- [x]` slice) — pick the one
 *      with most remaining slices. Finishes what was started.
 *   2. Fresh PRs (no checked slices) — fall back to the one with most
 *      unchecked slices.
 * Returns the first unchecked slice from the selected PR, or null if nothing.
 */
function discoverNextSlice(): DiscoveredSlice | null {
  const prsJson = sh(
    'gh pr list --state open --json number,headRefName,body --limit 30',
  );
  if (!prsJson) return null;

  let prs: { number: number; headRefName: string; body: string }[];
  try {
    prs = JSON.parse(prsJson);
  } catch {
    return null;
  }

  interface PRInfo {
    prNumber: number;
    prBranch: string;
    slices: Slice[];
    inProgress: boolean;
  }

  const candidates: PRInfo[] = [];

  for (const pr of prs) {
    // Parse unchecked checklist items: `- [ ] #N — Title` or `- [ ] #N - Title`
    const uncheckedMatches = [...pr.body.matchAll(/-\s*\[\s*\]\s*#(\d+)\s*[—\-]\s*(.+)/g)];
    if (uncheckedMatches.length === 0) continue;

    const slices: Slice[] = [];
    for (const m of uncheckedMatches) {
      const num = parseInt(m[1], 10);
      const title = m[2].trim();
      // Verify the issue has the ready-for-agent label
      const labels = sh(`gh issue view ${num} --json labels --jq '.labels[].name'`);
      if (labels.includes("ready-for-agent")) {
        slices.push({ num, title });
      }
    }

    if (slices.length === 0) continue;

    // A PR is in-progress if it already has at least one checked slice
    const hasChecked = [...pr.body.matchAll(/-\s*\[\s*x\s*\]\s*#\d+/g)].length > 0;

    candidates.push({
      prNumber: pr.number,
      prBranch: pr.headRefName,
      slices,
      inProgress: hasChecked,
    });
  }

  if (candidates.length === 0) return null;

  // Pass 1: in-progress PRs — finish what was started (most remaining first)
  const inProgress = candidates.filter((c) => c.inProgress);
  if (inProgress.length > 0) {
    inProgress.sort((a, b) => b.slices.length - a.slices.length);
    const best = inProgress[0];
    return {
      prNumber: best.prNumber,
      prBranch: best.prBranch,
      issueNumber: best.slices[0].num,
      issueTitle: best.slices[0].title,
    };
  }

  // Pass 2: fresh PRs — pick the one with most unchecked slices
  candidates.sort((a, b) => b.slices.length - a.slices.length);
  const best = candidates[0];
  return {
    prNumber: best.prNumber,
    prBranch: best.prBranch,
    issueNumber: best.slices[0].num,
    issueTitle: best.slices[0].title,
  };
}

// ---------------------------------------------------------------------------
// Standalone-issue discovery (priority 2 — fallback when no PR slices)
// ---------------------------------------------------------------------------

interface DiscoveredIssue {
  issueNumber: number;
  issueTitle: string;
}

/**
 * Find a standalone ready-for-agent issue not referenced in any open PR.
 * Returns the first such issue, or null if none available.
 */
function discoverStandaloneIssue(): DiscoveredIssue | null {
  const issuesJson = sh(
    'gh issue list --label ready-for-agent --json number,title,labels --limit 30',
  );
  if (!issuesJson) return null;

  let issues: { number: number; title: string; labels: { name: string }[] }[];
  try {
    issues = JSON.parse(issuesJson);
  } catch {
    return null;
  }

  if (issues.length === 0) return null;

  const issuesInPRs = getIssuesInPRs();

  for (const issue of issues) {
    // Skip issues already being worked on by another sandcastle instance
    if (issue.labels.some((l) => l.name === "sandcastle-in-progress")) continue;
    if (!issuesInPRs.has(issue.number)) {
      return { issueNumber: issue.number, issueTitle: issue.title };
    }
  }

  return null;
}

// ---------------------------------------------------------------------------
// Main loop
// ---------------------------------------------------------------------------

for (let iteration = 1; iteration <= MAX_ITERATIONS; iteration++) {
  console.log(`\n=== Iteration ${iteration}/${MAX_ITERATIONS} ===\n`);

  // Priority 1: PR slices
  const prSlice = discoverNextSlice();

  if (prSlice) {
    // ========== PR mode ==========
    console.log(`PR #${prSlice.prNumber} on branch "${prSlice.prBranch}"`);
    console.log(`Slice #${prSlice.issueNumber} — ${prSlice.issueTitle}`);

    // Rebase PR branch onto latest develop to prevent stale-base CI failures.
    // Without this, a PR that sits open while develop moves forward will fail CI
    // because the merge ref (refs/pull/N/merge) targets an old develop snapshot.
    const prevBranch = sh("git branch --show-current") || "develop";
    sh("git fetch origin develop 2>&1");
    sh(`git checkout ${prSlice.prBranch} 2>&1`);
    const rebaseResult = sh(`git rebase origin/develop 2>&1`);
    if (rebaseResult.toLowerCase().includes("conflict")) {
      console.error(`ERROR: Rebase conflict on ${prSlice.prBranch}. Skipping slice.`);
      console.error(rebaseResult);
      sh("git rebase --abort 2>&1");
      sh(`git checkout ${prevBranch} 2>&1`);
      continue;
    }
    console.log(`  git push --force-with-lease origin ${prSlice.prBranch}`);
    sh(`git push --force-with-lease origin ${prSlice.prBranch} 2>&1`);
    sh(`git checkout ${prevBranch} 2>&1`);

    const branch = `sandcastle/${prSlice.prBranch}/slice-${prSlice.issueNumber}`;

    const sandbox = await sandcastle.createSandbox({
      branch,
      baseBranch: prSlice.prBranch,
      sandbox: docker(),
      hooks,
      copyToWorktree,
    });

    let hasCommits = false;

    try {
      const implement = await sandbox.run({
        name: "implementer",
        maxIterations: 1,
        agent: sandcastle.pi("deepseek-v4-pro"),
        promptFile: "./.sandcastle/implement-prompt.md",
        promptArgs: {
          PR_NUMBER: String(prSlice.prNumber),
          PR_BRANCH: prSlice.prBranch,
          ISSUE_NUMBER: String(prSlice.issueNumber),
          ISSUE_TITLE: prSlice.issueTitle,
          BASE_BRANCH: prSlice.prBranch,
        },
      });

      hasCommits = implement.commits.length > 0;

      if (!hasCommits) {
        console.log("Implementation agent made no commits. Skipping to next slice.");
        continue;
      }

      console.log(`\nImplementation complete on branch: ${branch}`);
      console.log(`Commits: ${implement.commits.length}`);

      await sandbox.run({
        name: "reviewer",
        maxIterations: 1,
        agent: sandcastle.pi("deepseek-v4-pro"),
        promptFile: "./.sandcastle/review-prompt.md",
        promptArgs: {
          BRANCH: branch,
          BASE_BRANCH: prSlice.prBranch,
        },
      });

      console.log("\nReview complete.");
    } finally {
      await sandbox.close();

      if (hasCommits) {
        console.log(`\nMerging ${branch} into ${prSlice.prBranch}...`);
        sh(`git branch -f ${prSlice.prBranch} ${branch} 2>&1`);
        console.log(`PR branch ${prSlice.prBranch} updated.`);

        console.log(`  git push origin ${prSlice.prBranch}`);
        const pushResult = sh(`git push origin ${prSlice.prBranch} 2>&1`);
        console.log(pushResult || `  ${prSlice.prBranch} pushed.`);
      }
    }

    continue;
  }

  // Priority 2: Standalone issues (fallback)
  const standaloneIssue = discoverStandaloneIssue();

  if (standaloneIssue) {
    // ========== Standalone mode ==========
    console.log(`Standalone issue #${standaloneIssue.issueNumber} — ${standaloneIssue.issueTitle}`);

    // Mark as in-progress so other sandcastle instances skip it
    const addLabel = shCheck(
      `gh issue edit ${standaloneIssue.issueNumber} --add-label sandcastle-in-progress 2>&1`,
    );
    if (!addLabel.ok) {
      console.error(
        `ERROR: Failed to add sandcastle-in-progress label to #${standaloneIssue.issueNumber}: ${addLabel.out}`,
      );
      console.error("Skipping issue — label may not exist. Create it with:");
      console.error(
        `  gh label create sandcastle-in-progress --color "F9A825" --description "Sandcastle is currently working on this issue"`,
      );
      continue;
    }

    const branch = `sandcastle/issue-${standaloneIssue.issueNumber}`;

    // Ensure local develop is up to date before branching off it.
    sh("git fetch origin develop 2>&1 && git checkout develop 2>&1 && git merge --ff-only origin/develop 2>&1");

    const sandbox = await sandcastle.createSandbox({
      branch,
      baseBranch: "develop",
      sandbox: docker(),
      hooks,
      copyToWorktree,
    });

    let hasCommits = false;

    try {
      // If the branch already has commits beyond develop (previous run that was
      // never merged), skip the implementer and go straight to review+merge.
      const existingCommits = sh(`git rev-list develop..${branch} --count 2>&1`);
      if (existingCommits && parseInt(existingCommits, 10) > 0) {
        console.log(
          `Branch ${branch} already has ${existingCommits} commit(s) beyond develop — skipping implementation.`,
        );
        hasCommits = true;
      } else {
        const implement = await sandbox.run({
          name: "implementer",
          maxIterations: 1,
          agent: sandcastle.pi("deepseek-v4-pro"),
          promptFile: "./.sandcastle/implement-standalone-prompt.md",
          promptArgs: {
            ISSUE_NUMBER: String(standaloneIssue.issueNumber),
            ISSUE_TITLE: standaloneIssue.issueTitle,
          },
        });

        hasCommits = implement.commits.length > 0;
      }

      if (!hasCommits) {
        console.log("Implementation agent made no commits. Skipping to next issue.");
        continue;
      }

      console.log(`\nWork complete on branch: ${branch}`);

      await sandbox.run({
        name: "reviewer",
        maxIterations: 1,
        agent: sandcastle.pi("deepseek-v4-pro"),
        promptFile: "./.sandcastle/review-prompt.md",
        promptArgs: {
          BRANCH: branch,
          BASE_BRANCH: "develop",
        },
      });

      console.log("\nReview complete.");
    } finally {
      await sandbox.close();

      if (hasCommits) {
        console.log(`\nMerging ${branch} into develop...`);
        sh(`git branch -f develop ${branch} 2>&1`);
        console.log("develop updated.");

        console.log("  git push origin develop");
        const pushResult = sh("git push origin develop 2>&1");
        console.log(pushResult || "  develop pushed.");

        // Remove in-progress label and transition ready-for-agent → sandcastle-completed
        console.log(
          `  Transitioning labels on #${standaloneIssue.issueNumber}: ready-for-agent → sandcastle-completed...`,
        );
        const rmResult = shCheck(
          `gh issue edit ${standaloneIssue.issueNumber} --remove-label ready-for-agent,sandcastle-in-progress --add-label sandcastle-completed 2>&1`,
        );
        if (!rmResult.ok) {
          console.error(`  WARNING: Failed to remove labels: ${rmResult.out}`);
        }
      } else {
        // No commits made — keep sandcastle-in-progress so the issue is skipped
        // next iteration. Re-add ready-for-agent if a human rescues it later.
        console.log(
          `  Keeping sandcastle-in-progress label on #${standaloneIssue.issueNumber} to prevent re-discovery.`,
        );
      }
    }

    continue;
  }

  // Neither PR slices nor standalone issues — done.
  console.log("No unchecked ready-for-agent work found. Stopping.");
  break;
}

console.log("\nAll done.");
