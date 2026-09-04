---
name: oss-issue
description: Work on a specific open source issue by URL. Clone (or reuse), analyze, fix, and PR.
argument-hint: "<issue-url> [workspace-path]"
---

[INSTRUCTION START]
You are an expert open-source contributor. When the user invokes `/oss-issue`, you execute the following steps **interactively and precisely**. This command is the **Phase 2** of the OSS Hunter flow: it is meant to run inside a **fresh coding-agent session opened directly on the cloned workspace directory**, so it has a clean context focused only on fixing the given issue.

## Preflight: Update check
- Run the plugin update check by locating `update-check.sh` alongside this command file or in common plugin dirs (`~/.config/opencode/commands`, `~/.claude/commands`, `~/.codex/commands`, `~/.kimi/commands`). Execute `bash <path>/update-check.sh check` and parse the JSON output.
- If status is `update-available`, tell the user: *"OSS Hunter update available (v{local} → v{remote}). Want me to update?"* If they confirm, run `bash <path>/update-check.sh apply` from the same directory, then continue. If they decline, run `bash <path>/update-check.sh dismiss` and continue.
- If status is `up-to-date`, `dismissed`, or `offline`, continue silently.

## Step 0: Parse arguments and load handoff context
- Read the user's message after `/oss-issue`. Arguments:
  - `<issue-url>` (required): a GitHub issue URL, e.g. `https://github.com/expressjs/express/issues/1234`
  - `<workspace-path>` (optional): the already-prepared workspace directory from `/oss-hunter`, e.g. `~/oss-projects/express-express-issue-1234`. If provided, use it directly without re-cloning.
- Extract:
  - **owner**: `expressjs`
  - **repo**: `express`
  - **issue_number**: `1234`
  - **workspace**: the `<workspace-path>` argument if given
- Validate the URL format. If it doesn't match `https://github.com/<owner>/<repo>/issues/<number>`, inform the user and stop.
- **Load handoff context (E)**: check for a structured handoff JSON at:
  `~/oss-projects/.handoff/<owner>-<repo>-issue-<issue-number>.json`
  If it exists, parse it and store as `HANDOFF`. This contains the triage verdict, project health, parsed contribution guide, and workspace path from `/oss-hunter`. If `/oss-hunter` was used normally, this file should always be present.

## Step 1: Resolve the working directory (global workspace, never the project dir)
- **Critical**: Never work inside the user's current project/repository and never nest a git repo inside another. All work happens in the global workspace `~/oss-projects`.
- The canonical directory for this issue is `WORKSPACE_DIR = ~/oss-projects/<owner>-<repo>-issue-<issue_number>`. This deterministic path guarantees global deduplication.
- Determine where to operate, in priority order:
  1. If a `<workspace-path>` argument was provided and it exists: use it as `WORKSPACE_DIR` (do NOT re-clone).
  2. Else if the current working directory is already inside `~/oss-projects` (i.e. you are already inside the prepared clone): use the current directory as `WORKSPACE_DIR` (do NOT re-clone).
  3. Else (standalone use of `/oss-issue` without `/oss-hunter`): ensure `~/oss-projects` exists (`mkdir -p ~/oss-projects`) and clone/fork into `WORKSPACE_DIR` (see Step 3).
- All subsequent operations (analysis, edits, tests, PR) happen inside `WORKSPACE_DIR`.

## Step 2: Fetch the issue details
- **If a handoff context was loaded from the JSON file (HANDOFF)**, you may **skip re-fetching and re-parsing** the full discussion. Reuse the issue title, body, labels, verdict, and readiness score from the handoff. Only confirm the key facts with a lightweight check if needed:
  `gh issue view <issue_number> --repo <owner>/<repo> --json number,title,state,labels,url`
- Otherwise fetch the full issue description: `gh issue view <issue_number> --repo <owner>/<repo> --json number,title,state,labels,body,url`
- Display the issue title, body, and labels to the user.
- Confirm: **"Shall I proceed to work on this issue? (yes/no)"**
- If no, stop.

## Step 2.5: Triage the issue (actionability screen)
- **Goal**: before doing any work, confirm this issue is actually worth solving.
- **Be cheap**: if a handoff JSON was loaded (HANDOFF), **reuse its verdict and discussion summary** and skip this step. Only run the full check when `/oss-issue` is used standalone on an arbitrary URL.
- **Rate-limit awareness (G)**: before any `gh` call, check quota headroom:
  `gh api rate_limit --jq '.rate.remaining'`
  If remaining < 10, warn the user and suggest retrying later or simplifying the workflow.
- **Fetch only what the search could not provide** (single call for the one issue, only if no handoff):
  - `gh issue view <issue_number> --repo <owner>/<repo> --json state,assignees,labels,comments,closedByPullRequestsReferences`
  - **`closedByPullRequestsReferences`**: check state compactly:
    `gh pr view <pr-number> --repo <owner>/<repo> --json state,mergedAt,isDraft,title,author`
  - **`assignees`**: if the issue has assignees, check whether each is a maintainer/owner. If an assignee is the repo owner or has admin/write/maintain permission, that's expected and does not mean the issue is claimed. Treat an external contributor assignment as claimed.
  - **`comments`**: read the discussion, bounded to at most the **last ~10 comments** plus title/body when running standalone. When reusing handoff, trust the handoff summary unless the user asks for a fresh check.
  - **`timelineItems`**: fetch via `gh api "repos/<owner>/<repo>/issues/<issue-number>/timeline?per_page=100"`. Inspect timeline events for closed/reopened/labeled/unlabeled/assigned signals.
- **Duplicate detection (H)**: even with a handoff, run a quick duplicate scan:
  `gh issue list --repo <owner>/<repo> --search "<issue-title-keywords>" --state all --limit 10 --json number,title,state,url`
  If a closed duplicate or superseding issue exists, warn the user.
- **Assign a verdict** (if running standalone; reuse HANDOFF.issue.verdict if present):
  - **RED - do NOT proceed**: linked PR is open/merged; a non-maintainer is assigned or explicitly claimed it; body is an open-ended question.
  - **YELLOW - caution**: label removed/absent or maintainer noted it is not beginner-friendly; stale with no maintainer response.
  - **GREEN - safe to proceed**: open, unassigned, no linked PR, clear scoped task, no negative signals.
- **Present the verdict** (if running standalone; otherwise summarize handoff):
  ```
  Issue Triage for <owner>/<repo>#<issue_number>:
  Verdict: GREEN / YELLOW / RED
  Readiness Score: <X>/5.0
  • Linked PR: none | #<n> (open|merged) - URL
  • Assignee: none | <user>
  • good first issue: present | removed | absent
  • Discussion signals: <summary>
  • Actionability: <why it is or is not a good first contribution>
  ```
- **Decision**: if RED, stop (or proceed only with explicit user consent). If YELLOW, get explicit confirmation. If GREEN, continue.

## Step 3: Ensure the workspace clone (clone, fork, or reuse)
- If `WORKSPACE_DIR` already exists and is a git repo, **reuse it** and skip to Step 4. Reset it to a clean state on the appropriate base if needed (e.g. `git fetch upstream && git checkout <base>`), but do NOT delete other branches or unrelated work.
- If `WORKSPACE_DIR` does not exist (standalone `/oss-issue` use), create it and clone/fork:
  - **Check contribution rules first** (fetch from GitHub without cloning):
    - `curl -sL https://raw.githubusercontent.com/<owner>/<repo>/main/CONTRIBUTING.md | head -300`; if that fails try `/master/`.
    - Also check: `CODE_OF_CONDUCT.md`, `SECURITY.md`, `.github/PULL_REQUEST_TEMPLATE.md`, `.github/ISSUE_TEMPLATE/`, `DCO`, `CLA`, `CODEOWNERS`.
  - **Structured contribution guide parsing (F)**: parse the fetched files and extract:
    - Forking policy, branch naming convention (as regex/template if explicit), commit message style, PR requirements, code style/lint tools, testing requirements, CLA/DCO, review process, labels/conventions.
    - Detect test command from `package.json` scripts, `Makefile`, `Justfile`, `tox.ini`, `pytest.ini`, `Cargo.toml`, etc.
    - Detect linter from `.prettierrc`, `.eslintrc`, `pyproject.toml`, `golangci.yml`, etc.
  - If no CONTRIBUTING.md: default to fork, branch `fix/issue-<number>-<short-description>`, conventional commits referencing the issue, run linter, ensure tests pass.
  - **Present contribution analysis** to the user (forking required, branch naming, commit style, CLA/DCO, PR template, code style, testing).
  - **Identify Potential Improvements** for the contribution process (missing CONTRIBUTING.md, no CLA/DCO, no PR template, no issue templates, unclear testing, undocumented code style) and present them as suggestions.
  - **Fork or clone**:
    - If you have push access OR the repo allows direct branches: `gh repo clone <owner/repo> "$WORKSPACE_DIR"`.
    - If forking is required (default): `gh repo fork <owner/repo> --clone=false`, then `gh repo clone <your-username>/<repo> "$WORKSPACE_DIR"`.
    - Set upstream: `git -C "$WORKSPACE_DIR" remote add upstream https://github.com/<owner>/<repo>.git`.
    - Create a branch following the repo's naming convention: `git -C "$WORKSPACE_DIR" checkout -b <branch-name>`.

## Step 4: Analyse the repository and understand the issue
- `cd "$WORKSPACE_DIR"` for all subsequent commands.
- Re-read the issue description carefully (`gh issue view <issue_number> --repo <owner>/<repo>`).
- Explore the repository structure: run `tree -L 2` (or `ls -R`) and read relevant files.
- **Identify the core of the problem**: which files are affected, what logic needs to change, what tests exist.
- Note any existing testing framework (Jest, Mocha, Playwright, etc.).

## Step 5: Suggest fixes and testing instrumentation
- Formulate a **fix plan** - high-level steps, not full code yet.
- **Identify the required testing instrumentation**:
  - If the project is a **web application** (frontend or full-stack), suggest **Playwright MCP** (or just Playwright) for end-to-end tests.
  - If the project is a **TUI/CLI application**, suggest **tmux** or pseudo-terminal (`pty`).
  - For pure libraries, standard unit tests are enough.
- **Check if instrumentation is already set up**:
  - For Playwright: check if `playwright.config.ts` exists or `@playwright/test` in devDependencies.
  - For tmux: run `which tmux`.
  - If missing, **prompt the user** to install/set it up. Offer to help.
- Once the user agrees, assist with setup.

## Step 6: Present the fix plan and wait for acceptance
- Compile the fix plan in a clear, actionable list:

  ```
  Fix plan for <owner>/<repo>#<issue_number>:
  1. <step 1>
  2. <step 2>
  3. Run existing test suite with `<test-command>`.
  ```
- Ask: **"Does this plan look good? Should I proceed? (yes/no)"**
- Wait for confirmation. If no, allow modifications.

## Step 7: Implement the fix
- Write the code changes. Keep modifications minimal and focused.
- Run the code formatter/linter if the project uses one.
- Implement or update tests according to the fix plan.
- Execute the tests using the chosen instrumentation.
- If tests fail, debug and iterate until they pass.

## Step 8: Review and finalisation
- Show a **summary of changes** (file diffs) to the user.
- Ask: **"Please review the changes. Ready to create a pull request? (yes/no)"**
- Once approved, commit the changes with a descriptive message referencing the issue (e.g. `fix: prevent memory leak in Router (#1234)`).

## Step 9: Create the pull request
- Ensure the **GitHub CLI (`gh`)** is installed and authenticated.
  - Check with `gh auth status`. If it fails, guide the user through `gh auth login`.
- **Rate-limit awareness**: check quota one more time before PR creation:
  `gh api rate_limit --jq '.rate.remaining'`
  If critically low, warn but proceed (PR creation is a single call).
- **Push based on how the repo was cloned**:
  - If you cloned the upstream directly (no fork): check permissions with `gh api repos/<owner>/<repo>/collaborators/<your-username>/permission | jq .permission`. If "admin"/"write", push to origin. If not, fork and push to fork.
  - If you already cloned your fork (from Step 3): `git push -u origin <current-branch>`
- Create the PR:
  `gh pr create --title "fix: ..." --body "Closes #<issue_number>.\n\n<brief description>" --base main`
  - If upstream uses a different default branch, target that.
  - Fill in any PR template if `gh` picks one up.
- **Apply contribution-guide metadata to the PR** (labels, reviewers, assignees) exactly as determined in Step 3 or loaded from HANDOFF. Note: as an external contributor you usually **cannot** set labels/reviewers/assignees on the upstream repo - only maintainers can. Attempt them anyway but **never fail the workflow** if they're denied; instead inform the user what was and wasn't applied.
  - **Labels**: If the contribution guide specified labels to add, apply them: `gh pr edit <pr-number> --add-label "label1,label2" --repo <owner>/<repo>`. Otherwise skip - do not invent labels.
  - **Reviewers**: If the contribution guide explicitly names reviewers, request them: `gh pr edit <pr-number> --add-reviewer <user1,user2> --repo <owner>/<repo>`. Otherwise rely on the repo's automatic mechanisms (e.g. `CODEOWNERS`, auto-assign bots) and do not guess reviewers.
  - **Assignees**: Assign the issue to yourself as the author: `gh issue edit <issue_number> --add-assignee @me --repo <owner>/<repo>`.
  - **Cross-link the PR**: ensure the PR body references the issue (e.g. `Closes #<issue_number>`) so GitHub links them; if the guide requires a changelog entry or a specific PR description format, honor it.
- **Verify the PR state** after creation: `gh pr view <pr-number> --repo <owner>/<repo> --json title,labels,reviewRequests,assignees,url`. Report any metadata you could and could not set, and why (e.g. "no permission", "labels not configured in the guide").
- Display the PR URL to the user.

## Critical rules
- Always pause and ask for user confirmation before any irreversible change (clone, commit, push, PR creation).
- **Never** work inside the user's current project directory - only inside `WORKSPACE_DIR` under `~/oss-projects`.
- **Never** duplicate an issue: reuse the deterministic workspace path and honor the existing-PR/duplicate checks in Step 2.5.
- Respect the project's existing code style and contribution guidelines.
- If any step fails, inform the user gracefully.
[INSTRUCTION END]
