// Parallel Reviewer — implement-then-review, parallel per PR with blocker awareness
//
// Priority 1 — PR slices: rebases PR branch onto develop, then runs
//              implement+review for all UNBLOCKED unchecked slices in parallel
//              (Promise.allSettled), merges results back sequentially,
//              then repeats for newly-unblocked slices.
//
// Priority 2 — Standalone issues: fallback when no PR slices remain.
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

// Maximum rounds for the blocker-aware loop.
const MAX_ROUNDS = 10;

// Hooks run inside the sandbox before the agent starts each iteration.
const hooks = {
  sandbox: { onSandboxReady: [
    { command: "pwsh -NoProfile -Command Build-ModuleLocal" },
  ] },
};

// Copy node_modules from the host into the worktree (harmless for PowerShell projects).
const copyToWorktree = ["node_modules"];

// Docker sandbox config: host network + shared volume for PS5.1 smoke deployment.
const dockerSandbox = docker({
  network: "host",
  mounts: [{ hostPath: "/home/douda/Windows", sandboxPath: "/home/douda/Windows" }],
});

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

function sh(cmd: string): string {
  try {
    return execSync(cmd, { encoding: "utf-8", stdio: ["ignore", "pipe", "pipe"] }).trim();
  } catch (e: any) {
    const stderr = e.stderr?.toString().trim() || e.message;
    if (stderr) console.error(`  CMD FAILED: ${cmd}\n  ${stderr}`);
    return "";
  }
}

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
// PR-slice discovery
// ---------------------------------------------------------------------------

interface Slice {
  num: number;
  title: string;
  blockers: number[];  // issue numbers this slice depends on
}

interface PRTarget {
  prNumber: number;
  prBranch: string;
  slices: Slice[];
}

/**
 * Parse the "Blocked by" section from an issue body.
 * Returns array of issue numbers that block this slice.
 * "None" or missing → empty array (unblocked).
 */
function parseBlockers(body: string): number[] {
  const blockedMatch = body.match(/##\s*Blocked\s*by\s*\n([\s\S]*?)(?=\n##|$)/i);
  if (!blockedMatch) return [];

  const section = blockedMatch[1].trim();
  if (section.toLowerCase().includes("none")) return [];

  const nums: number[] = [];
  // Only match #NNN that appears right after a bullet (- #NNN).
  // Inline mentions like "Can be developed in parallel with #NNN" are
  // not blockers and won't match this pattern.
  for (const m of section.matchAll(/-\s*#(\d+)/g)) {
    nums.push(parseInt(m[1], 10));
  }
  return nums;
}

/**
 * Get the Set of issue numbers that are checked [x] in the PR checklist.
 */
function getCheckedIssues(prBody: string): Set<number> {
  const checked = new Set<number>();
  for (const m of prBody.matchAll(/-\s*\[\s*x\s*\]\s*#(\d+)/g)) {
    checked.add(parseInt(m[1], 10));
  }
  return checked;
}

/**
 * Find the best PR to work on and return ALL its UNBLOCKED unchecked
 * ready-for-agent slices in checklist order.
 *
 * A slice is unblocked when all its "Blocked by" issues are [x] in the PR.
 * Blocked slices are logged and skipped — they'll be picked up next round
 * after their blockers are completed.
 */
function discoverPRSlices(): PRTarget | null {
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

  interface PRCandidate {
    prNumber: number;
    prBranch: string;
    slices: Slice[];
    inProgress: boolean;
  }

  const candidates: PRCandidate[] = [];

  for (const pr of prs) {
    const uncheckedMatches = [...pr.body.matchAll(/-\s*\[\s*\]\s*#(\d+)\s*[—\-]\s*(.+)/g)];
    if (uncheckedMatches.length === 0) continue;

    const checkedIssues = getCheckedIssues(pr.body);

    const slices: Slice[] = [];
    for (const m of uncheckedMatches) {
      const num = parseInt(m[1], 10);
      const title = m[2].trim();

      const labels = sh(`gh issue view ${num} --json labels --jq '.labels[].name'`);
      if (!labels.includes("ready-for-agent")) continue;

      const body = sh(`gh issue view ${num} --json body --jq '.body'`);
      const blockers = parseBlockers(body);
      const isBlocked = blockers.some((b) => !checkedIssues.has(b));
      if (isBlocked) {
        console.log(`  #${num}: blocked by #${blockers.filter((b) => !checkedIssues.has(b)).join(", #")} — skipping`);
        continue;
      }

      slices.push({ num, title, blockers });
    }

    if (slices.length === 0) continue;

    const hasChecked = checkedIssues.size > 0;
    candidates.push({ prNumber: pr.number, prBranch: pr.headRefName, slices, inProgress: hasChecked });
  }

  if (candidates.length === 0) return null;

  const inProgress = candidates.filter((c) => c.inProgress);
  if (inProgress.length > 0) {
    inProgress.sort((a, b) => b.slices.length - a.slices.length);
    const best = inProgress[0];
    return { prNumber: best.prNumber, prBranch: best.prBranch, slices: best.slices };
  }

  candidates.sort((a, b) => b.slices.length - a.slices.length);
  const best = candidates[0];
  return { prNumber: best.prNumber, prBranch: best.prBranch, slices: best.slices };
}

// ---------------------------------------------------------------------------
// Standalone-issue discovery (priority 2)
// ---------------------------------------------------------------------------

interface DiscoveredIssue {
  issueNumber: number;
  issueTitle: string;
}

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
    if (issue.labels.some((l) => l.name === "sandcastle-in-progress")) continue;
    if (!issuesInPRs.has(issue.number)) {
      return { issueNumber: issue.number, issueTitle: issue.title };
    }
  }

  return null;
}

// ---------------------------------------------------------------------------
// PR checklist update helper
// ---------------------------------------------------------------------------

function updatePRChecklist(prNumber: number, issueNumber: number): void {
  const body = sh(`gh pr view ${prNumber} --json body --jq '.body'`);
  if (!body) return;

  const updated = body.replace(
    new RegExp(`(-\\s*\\[\\s*\\]\\s*#${issueNumber}\\b)`),
    (match) => match.replace("[ ]", "[x]"),
  );

  if (updated !== body) {
    const fs = require("fs");
    const tmpFile = `/tmp/pr-body-${prNumber}.md`;
    fs.writeFileSync(tmpFile, updated);
    sh(`gh pr edit ${prNumber} --body-file ${tmpFile} 2>&1`);
    fs.unlinkSync(tmpFile);
    console.log(`  PR checklist updated: - [x] #${issueNumber}`);
  }
}

// ---------------------------------------------------------------------------
// Main loop
// ---------------------------------------------------------------------------

console.log("=== Sandcastle Parallel ===\n");

let prTarget = discoverPRSlices();

if (prTarget) {
  // ===================================================================
  // PR mode — blocker-aware rounds
  //
  // Each round: rebase → discover UNBLOCKED slices → run in parallel →
  // merge sequentially. Blocked slices wait until their blockers are
  // checked [x], then get picked up in the next round.
  // ===================================================================
  let totalMerged = 0;

  for (let round = 1; round <= MAX_ROUNDS; round++) {
    prTarget = discoverPRSlices();

    if (!prTarget || prTarget.slices.length === 0) {
      console.log("No unblocked slices remaining.");
      break;
    }

    console.log(`\n=== Round ${round} ===`);
    console.log(`PR #${prTarget.prNumber} on branch "${prTarget.prBranch}"`);
    console.log(`${prTarget.slices.length} unblocked slice(s):`);
    for (const s of prTarget.slices) {
      console.log(`  #${s.num} — ${s.title}`);
    }
    console.log("");

    // Rebase PR branch onto latest develop (in isolated worktree so the
    // main working tree never leaves its current branch).
    const mergeWorktree = `.sandcastle/worktrees/mrg-${prTarget.prBranch}`;
    sh(`rm -rf ${mergeWorktree} 2>&1`);
    sh("git worktree prune 2>&1");
    sh(`git worktree add -f ${mergeWorktree} ${prTarget.prBranch} 2>&1`);
    sh(`git -C ${mergeWorktree} fetch origin develop 2>&1`);
    const rebaseResult = sh(`git -C ${mergeWorktree} rebase origin/develop 2>&1`);
    if (rebaseResult.toLowerCase().includes("conflict")) {
      console.error(`ERROR: Rebase conflict on ${prTarget.prBranch}. Skipping round.`);
      sh(`git -C ${mergeWorktree} rebase --abort 2>&1`);
      sh(`git worktree remove ${mergeWorktree} 2>&1`);
      continue;
    }
    sh(`git -C ${mergeWorktree} push --force-with-lease origin ${prTarget.prBranch} 2>&1`);

    // -----------------------------------------------------------------
    // Phase: Execute + Review (parallel)
    //
    // All unblocked slices run concurrently. Each gets its own sandbox
    // with implementer (2 iters) + reviewer (1 iter).
    // -----------------------------------------------------------------
    const settled = await Promise.allSettled(
      prTarget.slices.map(async (slice) => {
        const branch = `sandcastle/${prTarget!.prBranch}/slice-${slice.num}`;

        const sandbox = await sandcastle.createSandbox({
          branch,
          baseBranch: prTarget!.prBranch,
          sandbox: dockerSandbox,
          hooks,
          copyToWorktree,
        });

        let hasCommits = false;
        let implementCommits: number = 0;
        let reviewCommits: number = 0;

        try {
          const implement = await sandbox.run({
            name: "implementer",
            maxIterations: 2,
            agent: sandcastle.pi("deepseek-v4-flash"),
            promptFile: "./.sandcastle/implement-prompt.md",
            promptArgs: {
              PR_NUMBER: String(prTarget!.prNumber),
              PR_BRANCH: prTarget!.prBranch,
              ISSUE_NUMBER: String(slice.num),
              ISSUE_TITLE: slice.title,
              BASE_BRANCH: prTarget!.prBranch,
            },
          });

          hasCommits = implement.commits.length > 0;
          implementCommits = implement.commits.length;

          if (!hasCommits) {
            console.log(`  #${slice.num}: no commits — skipping`);
            return { slice, success: false, reason: "no-commits" };
          }

          console.log(`  #${slice.num}: implemented (${implementCommits} commit(s))`);

          const review = await sandbox.run({
            name: "reviewer",
            maxIterations: 1,
            agent: sandcastle.pi("deepseek-v4-pro"),
            promptFile: "./.sandcastle/review-prompt.md",
            promptArgs: {
              BRANCH: branch,
              BASE_BRANCH: prTarget!.prBranch,
            },
          });

          reviewCommits = review.commits.length;
          console.log(`  #${slice.num}: reviewed (${reviewCommits} commit(s))`);

          return { slice, sandbox, branch, success: true, implementCommits, reviewCommits };
        } catch (e: any) {
          console.error(`  #${slice.num}: ERROR — ${e.message}`);
          return { slice, success: false, reason: "exception", error: e.message };
        } finally {
          if (!hasCommits) await sandbox.close();
        }
      }),
    );

    // -----------------------------------------------------------------
    // Phase: Merge (sequential, in checklist order)
    //
    // Merges respect the PR checklist order. Each merge pushes so
    // subsequent merges have the latest base. Conflicts abort that
    // slice but don't block the others.
    // -----------------------------------------------------------------
    console.log("\n=== Merging ===\n");

    let mergeCount = 0;
    for (const [i, outcome] of settled.entries()) {
      const slice = prTarget.slices[i]!;

      if (outcome.status === "rejected") {
        console.error(`  ✗ #${slice.num}: sandbox failed — ${outcome.reason}`);
        continue;
      }

      const result = outcome.value as any;
      if (!result.success) {
        console.log(`  ✗ #${slice.num}: ${result.reason}`);
        continue;
      }

      const branch = result.branch as string;

      console.log(`  Merging #${slice.num} (${branch})...`);
      const mergeResult = sh(
        `git -C ${mergeWorktree} merge ${branch} --no-ff -m "merge: slice #${slice.num} — ${slice.title}" 2>&1`,
      );

      if (!mergeResult || mergeResult.toLowerCase().includes("conflict")) {
        console.error(`  ✗ #${slice.num}: MERGE CONFLICT — needs manual resolution`);
        sh(`git -C ${mergeWorktree} merge --abort 2>&1`);
        if (result.sandbox) await result.sandbox.close();
        continue;
      }

      mergeCount++;
      totalMerged++;

      sh(`git -C ${mergeWorktree} push origin ${prTarget.prBranch} 2>&1`);

      updatePRChecklist(prTarget.prNumber, slice.num);
      if (result.sandbox) await result.sandbox.close();

      console.log(`  ✓ #${slice.num}: ${result.implementCommits + result.reviewCommits} commit(s) merged`);
    }

    // Clean up merge worktree.
    sh(`git worktree remove ${mergeWorktree} 2>&1`);

    console.log(`\nRound ${round}: ${mergeCount}/${prTarget.slices.length} merged (total: ${totalMerged})`);
  }

  // Final status
  const remaining = discoverPRSlices();
  if (remaining && remaining.slices.length > 0) {
    console.log(`\n${remaining.slices.length} slice(s) still unchecked (failed or still blocked).`);
    console.log("Run sandcastle again to retry.");
  } else {
    console.log("\n🎉 All PR slices complete.");
  }
} else {
  // ===================================================================
  // Standalone mode (fallback)
  // ===================================================================
  console.log("No PR slices found. Checking standalone issues...");

  const standaloneIssue = discoverStandaloneIssue();

  if (standaloneIssue) {
    console.log(`Standalone issue #${standaloneIssue.issueNumber} — ${standaloneIssue.issueTitle}`);

    const addLabel = shCheck(
      `gh issue edit ${standaloneIssue.issueNumber} --add-label sandcastle-in-progress 2>&1`,
    );
    if (!addLabel.ok) {
      console.error(`ERROR: Failed to add sandcastle-in-progress label.`);
      process.exit(1);
    }

    const branch = `sandcastle/issue-${standaloneIssue.issueNumber}`;
    sh("git fetch origin develop 2>&1 && git checkout develop 2>&1 && git merge --ff-only origin/develop 2>&1");

    const sandbox = await sandcastle.createSandbox({
      branch,
      baseBranch: "develop",
      sandbox: dockerSandbox,
      hooks,
      copyToWorktree,
    });

    let hasCommits = false;

    try {
      const existingCommits = sh(`git rev-list develop..${branch} --count 2>&1`);
      if (existingCommits && parseInt(existingCommits, 10) > 0) {
        console.log(`Branch ${branch} already has commits — skipping implementation.`);
        hasCommits = true;
      } else {
        const implement = await sandbox.run({
          name: "implementer",
          maxIterations: 2,
          agent: sandcastle.pi("deepseek-v4-flash"),
          promptFile: "./.sandcastle/implement-standalone-prompt.md",
          promptArgs: {
            ISSUE_NUMBER: String(standaloneIssue.issueNumber),
            ISSUE_TITLE: standaloneIssue.issueTitle,
          },
        });
        hasCommits = implement.commits.length > 0;
      }

      if (!hasCommits) {
        console.log("No commits. Skipping.");
      } else {
        console.log(`Work complete on branch: ${branch}`);
        await sandbox.run({
          name: "reviewer",
          maxIterations: 1,
          agent: sandcastle.pi("deepseek-v4-pro"),
          promptFile: "./.sandcastle/review-prompt.md",
          promptArgs: { BRANCH: branch, BASE_BRANCH: "develop" },
        });
        console.log("Review complete.");
      }
    } finally {
      await sandbox.close();

      if (hasCommits) {
        sh(`git update-ref refs/heads/develop ${branch} 2>&1`);
        sh("git push origin develop 2>&1");
        console.log("develop updated and pushed.");

        shCheck(
          `gh issue edit ${standaloneIssue.issueNumber} --remove-label ready-for-agent,sandcastle-in-progress --add-label sandcastle-completed 2>&1`,
        );
      }
    }
  } else {
    console.log("No work found. Stopping.");
  }
}

console.log("\nAll done.");
