---
name: oss-hunter
description: Find and fix open source issues from your terminal. Sort by repo stars (default) or recently updated.
argument-hint: "<keywords...> [--limit N] [--sort stars|updated] [--skills list]"
---

[INSTRUCTION START]
You are an expert open-source contributor. When the user invokes `/oss-hunter`, you execute the following steps **interactively and precisely**.

## Step 0: Parse arguments
- Read the user's message after `/oss-hunter`. Extract:
  - **keywords**: a list of languages, frameworks, or topics (e.g. `js`, `typescript`, `react`, `go`)
  - **skills** / **stack**: extract via `--skills <list>` or `--stack <list>` flag (e.g., `--skills react,redux,typescript,antd`).
  - **limit**: use `--limit N` flag, or a bare integer at the end after keywords (e.g. `/oss-hunter js 10`). If not provided, default to **5**. If provided but >25, cap it to **25**.
  - **sort**: use `--sort updated` or `--sort stars`. If the last bare word after keywords is `stars` or `updated`, treat it as sort mode. Default to **updated** (fresh, active issues) — this is the cheapest and best signal for actionability. `stars` (repo popularity) is optional and requires a few extra calls to enrich the final small list.
  Example: `/oss-hunter js, ts, go --limit 20 --sort stars` -> keywords: `js ts go`, limit: 20, sort: stars.
  Example (shorthand): `/oss-hunter js 10 stars` -> keywords: `js`, limit: 10, sort: stars.
  Example (with skills): `/oss-hunter --skills react,redux,typescript,antd --limit 10` -> skills: `react,redux,typescript,antd`, limit: 10.

## Step 0.5: Determine Skill Profile & Preferences
- Resolve the Skill Profile:
  1. **Direct parameter**: If `--skills` or `--stack` was provided, parse it as a list.
  2. **Global Config**: Check `~/.config/oss-hunter/config.json`. If it exists, load saved skills and updatedAt.
  3. **Interactive Prompt**: If no skills/keywords and no global profile:
     - Ask: *"What is your preferred tech stack/skills? (e.g. react, typescript, redux, antd)"*
     - Use response as active Skill Profile.
     - Ask: *"Would you like to save this as your default profile in ~/.config/oss-hunter/config.json? (yes/no)"*
     - If yes, create dir and write: `{"skills": ["react", "typescript", ...], "updatedAt": "<ISO-8601>"}`.
- **Learning memory**: append every explored issue to `~/.config/oss-hunter/history.json` as an array entry:
  `{"issue": "owner/repo#123", "verdict": "GREEN|YELLOW|RED", "outcome": "skipped|started|completed|abandoned", "date": "<ISO-8601>", "skillsUsed": [...]}`. Create the file if missing. Use it to avoid re-surfacing issues the user already tried, and to rank keywords by past success rate.

## Step 1: Understand the global workspace model
- **Critical**: The plugin NEVER clones into the user's current project/repository, and it NEVER nests git repos inside other git repos. All cloned/forked repos live in a single **global workspace** in the home directory.
- The global workspace root is `$HOME/oss-projects` (i.e. `~/oss-projects`).
- Each issue gets a **deterministic, globally-unique directory**: `~/oss-projects/<owner>-<repo>-issue-<issue-number>`.
- You will only **find, select, clone, and hand off** in this command. The actual code analysis, fix, and PR creation happen in a **separate, fresh coding-agent session** run by `/oss-issue` directly inside the cloned directory.

## Step 2: Find open issues by keywords (multi-signal search)
- Use the **keywords** and active **Skill Profile**.
- If no keywords were explicitly provided but a Skill Profile is active, use the terms from the Skill Profile as the search keywords.
- **This step is a SMALL set of parallel GitHub search calls** — do NOT use "find repos, then search each repo" loops.
- Run **three parallel searches** with OR-style label coverage (comma-separated labels per call, merge results client-side):
   1. `gh search issues <keywords...> --label "good first issue,good-first-issue,help wanted" --state open --sort updated --order desc --limit <limit> --json number,title,repository,labels,assignees,updatedAt,commentsCount,url`
   2. `gh search issues <keywords...> --label "first-timers-only,up-for-grabs,beginner-friendly" --state open --sort updated --order desc --limit <limit> --json number,title,repository,labels,assignees,updatedAt,commentsCount,url`
   3. `gh search issues <keywords...> --label "easy,starter,good-first-bug,contribution-welcome" --state open --sort updated --order desc --limit <limit> --json number,title,repository,labels,assignees,updatedAt,commentsCount,url`
- Merge the three result sets and deduplicate by issue URL. Collect up to **`limit`** distinct issues.
- **Semantic fallback** (if merged results are fewer than `limit`): run one more broad search without labels:

  Post-filter by repo reputation and title patterns that suggest small, scoped tasks (e.g. "fix typo", "broken link", "update example", "add missing test", "handle edge case"). Do not invent labels for these — surface them with a note that they are unlabeled but appear beginner-friendly.
- **`--sort stars` (optional enrichment)**: GitHub cannot star-sort issues in one call. If the user explicitly requested `--sort stars`:
  - Run the three parallel searches above (limit = 2x desired), merge/deduplicate, then for **only the final candidates you intend to display** (a handful, <= limit), fetch their repo star counts: `gh repo view <owner>/<repo> --json stargazerCount,nameWithOwner`. Re-sort by stars locally.
- **Relevancy ranking**:
  - Default (`updated`): order by freshness, then prefer well-known/reputable repos; discard suspicious/empty/no-activity repos.
  - `stars`: order by repo popularity.
- Each entry must include: repository full name with star count (if known), issue number and title, issue URL, issue description snippet.
- **Skill verification (I)**: for each candidate, cheaply verify the repo actually uses the claimed skills. Check for signal files: `package.json` for JS/TS ecosystems, `go.mod` for Go, `Cargo.toml` for Rust, `requirements.txt`/`pyproject.toml` for Python, `pom.xml`/`build.gradle` for Java, etc. If the repo does not match the skill profile, demote or discard it.

## Step 3: Present list and let user choose
- Display the list in a numbered, readable format:
  ```
  I found the following issues:

  1. expressjs/express #1234 - "Memory leak in Router" (https://github.com/expressjs/express/issues/1234)
  2. nestjs/nest #5678 - "Invalid pipe transformation for arrays"
  ...
  ```
- Ask: **"Which issue would you like to work on? (enter number or 'none')"**
- Wait for the user's response. If they type "none" or cancel, stop the workflow.
- Validate the selection and note the chosen repository, issue number, and issue URL.

## Step 3.5: Triage the issue (deep actionability screen)
- **Goal**: never waste the user's first-contribution effort on an issue that is already solved, already claimed, or not actually beginner-friendly. Before recommending or cloning, deeply inspect the issue **including its full discussion**, never title/labels alone.
- Compute the canonical workspace path: `WORKSPACE_DIR=~/oss-projects/<owner>-<repo>-issue-<issue-number>`.
- **Be cheap**: reuse what Step 2 already returned inline. Only fetch extra data once for the single selected issue.
- **Rate-limit awareness (G)**: before any `gh` call, check quota headroom:
  `gh api rate_limit --jq '.rate.remaining'`
  If remaining < 10, warn the user and suggest retrying later or using `--limit` smaller. Do not start a 10-step workflow with insufficient quota.
- **Fetch linked PRs and the full discussion (one call each):**
  - `gh issue view <issue-number> --repo <owner>/<repo> --json state,assignees,labels,comments,closedByPullRequestsReferences`
  - **`closedByPullRequestsReferences`**: For each, check state compactly:
    `gh pr view <pr-number> --repo <owner>/<repo> --json state,mergedAt,isDraft,title,author`
  - **`assignees`**: if the issue has assignees, check whether each is a maintainer/owner. If an assignee is the repo owner or has admin/write/maintain permission, that's expected and does not mean the issue is claimed. Treat an external contributor assignment as claimed.
  - **`comments`**: read the **full discussion**, not just the last 10. For each comment, capture: author, authorAssociation (MEMBER/OWNER/CONTRIBUTOR/NONE), createdAt, body. Signals to detect:
    - Someone claiming it ("I'll work on this", "beginning to work on a fix", "assigned to me", "taking this")
    - An already-opened PR ("I opened a PR", "dev work is complete", "PR awaiting review", PR URL in body/comments)
    - A maintainer downgrading it ("I removed the label", "requires a fix at a higher level", "too complex", "out of scope", "this is a feature request not a bug")
    - Staleness ("Is anyone still working on this?", no activity in months)
    - Ambiguity: the body is a question/discussion rather than a concrete, scoped task
    - Maintainer engagement: did a maintainer reply? How quickly? Is the issue being actively shepherded?
  - **`timelineItems`**: fetch via `gh api "repos/<owner>/<repo>/issues/<issue-number>/timeline?per_page=100"`. Inspect timeline events (closed, reopened, labeled, unlabeled, assigned, unassigned, locked, unlocked, milestone changes, cross-referenced) for additional signals that comments alone miss.
- **Project health pre-screen (B)**: before scoring the issue, evaluate the repository:
  - `gh api repos/<owner>/<repo> --jq '{stars: .stargazers_count, forks: .forks_count, openIssues: .open_issues_count, defaultBranch: .default_branch, license: .license.spdx_id, createdAt: .created_at, updatedAt: .updated_at}'`
  - Check for community health files: `curl -sL https://raw.githubusercontent.com/<owner>/<repo>/main/CODE_OF_CONDUCT.md | head -5` and `https://raw.githubusercontent.com/<owner>/<repo>/main/SECURITY.md | head -5`. If `/main/` fails, try `/master/`.
  - Recent commit activity: `gh api repos/<owner>/<repo>/commits?per_page=1 --jq '.[0].commit.committer.date'`
  - Present a compact health summary:
    ```
    Project Health for <owner>/<repo>:
    • Stars/Forks: <stars>/<forks>
    • Last commit: <date> (<X> days ago)
    • CODE_OF_CONDUCT: present | missing
    • SECURITY.md: present | missing
    • License: <name> | missing
    ```
- **Evaluate against rules and assign a verdict:**
  - **RED - do NOT recommend**: linked PR is open or merged; a non-maintainer is assigned or explicitly claimed it in comments; body is an open-ended question with no clear task.
  - **YELLOW - caution**: `good first issue` label removed/absent or maintainer noted it is not beginner-friendly; stale with no maintainer response; multiple people asked to work on it.
  - **GREEN - safe to proceed**: open, unassigned, no linked PR, clear scoped task, no negative signals.
- **First-Step Readiness Score (D)**: compute a score from 0.0 to 5.0 based on:
  - **Issue clarity** (0-1): reproduction steps present? Acceptance criteria defined? Code snippets or file references included?
  - **Discussion maturity** (0-1): maintainer engaged? Ambiguity resolved? Last activity within 30 days?
  - **Project welcoming** (0-1): CODE_OF_CONDUCT present? PR review responsiveness implied by recent merged PRs? Contributor diversity visible?
  - **Setup cost** (0-1): estimated from repo size, language, build system complexity (1 = trivial, 0 = likely >30 min setup). Estimate cheaply: presence of `package-lock.json`/`yarn.lock`/`pnpm-lock.yaml` implies standard JS/TS setup; `Dockerfile` or `devcontainer.json` implies reproducible setup; absence of both and a large repo implies higher cost.
  - **Skill match** (0-1): does the repo actually use the user's claimed skills? Did the discussion reference skills the user claimed?
  - **Claim risk** (0-1): are multiple people expressing interest in comments? Is there an active but stale PR?
  Display the score alongside the verdict. A score below 2.5 should bump GREEN to YELLOW or YELLOW to RED.
- **Present the verdict clearly** before any clone:
  ```
  Issue Triage for <owner>/<repo>#<issue-number>:
  Verdict: 🟢 GREEN / 🟡 YELLOW / 🔴 RED
  Readiness Score: <X>/5.0
  • Linked PR: none | #<n> (open|merged) - URL
  • Assignee: none | <user>
  • Labels: <comma-separated>
  • Discussion: <summary of comment authors, maintainer engagement, claims>
  • Project Health: <stars, last commit age, CoC presence>
  • Actionability: <why it is or is not a good first contribution>
  ```
  (Use a 🟢/🟡/🔴 marker in text, and an ASCII "GREEN/YELLOW/RED" word so it is unambiguous.)
- **Decision logic**:
  - If **RED**, warn clearly and recommend picking a different issue (loop back to Step 3). If the user insists, proceed with their explicit consent.
  - If **YELLOW**, surface the concern and the readiness score and ask the user to confirm they want to proceed.
  - If **GREEN**, proceed.
- Also perform **global duplicate detection (H)**:
  - If `WORKSPACE_DIR` already exists and contains a git repo (`.git`): it was already checked out before. Inspect `git -C "$WORKSPACE_DIR" log --oneline -5` and `branch -a`; REUSE it rather than re-cloning.
  - Search for duplicates/related issues: `gh issue list --repo <owner>/<repo> --search "<issue-title-keywords>" --state all --limit 10 --json number,title,state,url`. If a closed duplicate exists, warn the user.

## Step 4: Ensure the workspace clone (clone or reuse)
- Ensure the global workspace root exists: `mkdir -p ~/oss-projects`.
- If `WORKSPACE_DIR` already exists and is a git repo, **reuse it** (do not re-clone). Skip straight to the contribution analysis below, then to the handoff.
- Otherwise, create it and clone/fork into it:
  - **Before cloning, check contribution rules**:
    - Look for `CONTRIBUTING.md` or `CONTRIBUTING` in the repo root (fetch from GitHub without cloning first):
      `curl -sL https://raw.githubusercontent.com/<owner>/<repo>/main/CONTRIBUTING.md | head -300`
      If that fails, try `/master/` instead of `/main/`.
    - Also check: `CODE_OF_CONDUCT.md`, `SECURITY.md`, `.github/PULL_REQUEST_TEMPLATE.md`, `.github/ISSUE_TEMPLATE/`, `DCO`, `CLA`, `CODEOWNERS`.
  - **Structured contribution guide parsing (F)**: actually parse the fetched files and extract:
    - **Forking policy**: does it require forking?
    - **Branch naming convention**: look for explicit patterns (e.g. `fix/issue-1234`, `feature/...`, `<username>/fix-...`). Extract as a regex or template if present.
    - **Commit message style**: conventional commits? angular? gitmoji? Must reference issue number?
    - **PR requirements**: signed commits? linked issue? changelog entry? PR template checklist items?
    - **Code style**: linter/formatter to run? Detect from `package.json` scripts, `Makefile`, `Justfile`, `.prettierrc`, `.eslintrc`, `pyproject.toml`, etc.
    - **Testing requirements**: must all tests pass? must add tests? Detect test command from config files.
    - **CLA/DCO requirements**: is a CLA or DCO sign-off required?
    - **Review process**: how many approvals needed? review timeline?
    - **Labels/conventions**: any specific labels to use?
  - If no CONTRIBUTING.md exists, use these sensible defaults:
    - Fork the repo
    - Branch name: `fix/issue-<number>-<short-description>`
    - Commit messages: conventional commits (`fix: ...`, `feat: ...`) with issue reference
    - Run linter if config found, ensure tests pass
  - **Present contribution analysis to user**:
    ```
    Contribution Analysis for <owner>/<repo>:
    ┌─────────────────────────┬─────────────────────────────────────┐
    │ Requirement             │ Details                             │
    ├─────────────────────────┼─────────────────────────────────────┤
    │ Forking Required        │ Yes/No                              │
    │ Branch Naming           │ <convention>                        │
    │ Commit Style            │ <style>                             │
    │ CLA/DCO                 │ Required/Not Required/Unknown       │
    │ PR Template             │ Yes/No                              │
    │ Code Style              │ <tools>                             │
    │ Testing                 │ <requirements>                      │
    └─────────────────────────┴─────────────────────────────────────┘
    ```
  - **Identify Potential Improvements** for the repository's contribution process and present them as suggestions.
  - **Fork or clone based on contribution rules**:
    - If you have push access OR the repo allows direct branches: `gh repo clone <owner/repo> "$WORKSPACE_DIR"`.
    - If forking is required (default): first fork via `gh repo fork <owner/repo> --clone=false`, then clone your fork into the workspace:
      `gh repo clone <your-username>/<repo> "$WORKSPACE_DIR"` (or `git clone https://github.com/<your-username>/<repo>.git "$WORKSPACE_DIR"`)
    - After cloning your fork, set the upstream remote: `git -C "$WORKSPACE_DIR" remote add upstream https://github.com/<owner>/<repo>.git`
    - Create a new branch following the repo's naming convention:
      `git -C "$WORKSPACE_DIR" checkout -b <branch-name>`
  - Confirm the workspace is prepared and note the path.

## Step 5: Hand off to a fresh coding-agent session via `/oss-issue`
- **Do NOT analyze the codebase, write fixes, or create the PR in this session.** Doing so mixes contexts and confuses the agent. Instead, start a **fresh coding-agent session opened directly on the cloned directory** and pass the issue to `/oss-issue`.
- **Structured handoff file (E)**: write a JSON file at `~/oss-projects/.handoff/<owner>-<repo>-issue-<issue-number>.json` containing all context so `/oss-issue` can short-circuit its own triage and honor conventions without re-fetching everything:
  ```json
  {
    "generatedAt": "<ISO-8601>",
    "issue": {
      "url": "<issue-url>",
      "number": <number>,
      "title": "<title>",
      "verdict": "GREEN|YELLOW|RED",
      "readinessScore": <0.0-5.0>,
      "labels": ["good first issue", "bug"],
      "assignee": null | "<user>",
      "linkedPRs": [{"number": <n>, "state": "open|merged", "url": "<url>"}],
      "discussionSummary": "<2-3 sentence summary of comment signals>"
    },
    "projectHealth": {
      "stars": <count>,
      "forks": <count>,
      "lastCommitDaysAgo": <number>,
      "hasCoC": true|false,
      "hasSecurityPolicy": true|false,
      "license": "<name>|missing"
    },
    "contributionGuide": {
      "forkingRequired": true|false,
      "branchNaming": "<convention>",
      "commitStyle": "<style>",
      "claDco": "Required|Not Required|Unknown",
      "prTemplate": true|false,
      "codeStyle": "<tools>",
      "testing": "<requirements>"
    },
    "workspace": "~/oss-projects/<owner>-<repo>-issue-<issue-number>"
  }
  ```
- Present the handoff:
  ```
  Workspace ready: ~/oss-projects/<owner>-<repo>-issue-<issue-number>
  Issue: <issue-url>
  Verdict: <GREEN/YELLOW/RED> | Readiness: <X>/5.0

  Next: open a new coding-agent session in that directory and run:
    /oss-issue <issue-url> <workspace-path>

  E.g. /oss-issue https://github.com/<owner>/<repo>/issues/<issue-number> ~/oss-projects/<owner>-<repo>-issue-<issue-number>
  ```
- **Start the fresh session** (prefer to launch it for the user so the work continues automatically):
  - **OpenCode**: open the TUI in the workspace dir with `opencode ~/oss-projects/<owner>-<repo>-issue-<issue-number>`, or run headless with `opencode run --dir ~/oss-projects/<owner>-<repo>-issue-<issue-number> "/oss-issue <issue-url> <workspace-path>"`.
  - **Claude Code**: `cd ~/oss-projects/<owner>-<repo>-issue-<issue-number> && claude`
  - **Codex**: `cd ~/oss-projects/<owner>-<repo>-issue-<issue-number> && codex`
  - **Kimi**: `cd ~/oss-projects/<owner>-<repo>-issue-<issue-number> && kimi`
- If the current agent cannot launch a nested interactive session, pause and tell the user the exact command to run (above), and ask them to confirm once they've opened the new session in the workspace directory.

## Critical rules
- Always pause and ask for user confirmation before any irreversible change (fork, clone, commit, push, PR creation).
- **Never** clone, create files, or modify anything inside the user's current project directory. All work happens under `~/oss-projects`.
- **Never** duplicate an issue: the deterministic workspace path and the existing-PR/duplicate checks in Step 3.5 prevent this.
- Do not analyze, fix, or open a PR from this discovery command - that is the job of the fresh `/oss-issue` session.
- If any step fails (e.g. search returns no results), inform the user gracefully and suggest trying different keywords.
[INSTRUCTION END]
