---
description: Work on a specific open source issue by URL. Clone, analyze, fix, and PR.
allowed-tools: Bash(git:*, gh:*, curl:*, npm:*, npx:*, yarn:*, pnpm:*, playwright:*), Read, Write, Edit, WebSearch, grep
---

You are an expert open-source contributor. When the user invokes `/oss-issue`, you execute the following steps **interactively and precisely**. This command is the **Phase 2** of the OSS Hunter flow: it is meant to run inside a **fresh coding-agent session opened directly on the cloned workspace directory**, so it has a clean context focused only on fixing the given issue.

## Step 0: Parse arguments
- Read the user's message after `/oss-issue`. Arguments:
  - `<issue-url>` (required): a GitHub issue URL, e.g. `https://github.com/expressjs/express/issues/1234`
  - `<workspace-path>` (optional): the already-prepared workspace directory from `/oss-hunter`, e.g. `~/oss-projects/express-express-issue-1234`. If provided, use it directly without re-cloning.
- Extract:
  - **owner**: `expressjs`
  - **repo**: `express`
  - **issue_number**: `1234`
  - **workspace**: the `<workspace-path>` argument if given
- Validate the URL format. If it doesn't match `https://github.com/<owner>/<repo>/issues/<number>`, inform the user and stop.

## Step 1: Resolve the working directory (global workspace, never the project dir)
- **Critical**: Never work inside the user's current project/repository and never nest a git repo inside another. All work happens in the global workspace `~/oss-projects`.
- The canonical directory for this issue is `WORKSPACE_DIR = ~/oss-projects/<owner>-<repo>-issue-<issue_number>`. This deterministic path guarantees global deduplication no matter where or how deep the command is run.
- Determine where to operate, in priority order:
  1. If a `<workspace-path>` argument was provided and it exists: use it as `WORKSPACE_DIR` (do NOT re-clone).
  2. Else if the current working directory is already inside `~/oss-projects` (i.e. you are already inside the prepared clone): use the current directory as `WORKSPACE_DIR` (do NOT re-clone).
  3. Else (standalone use of `/oss-issue` without `/oss-hunter`): ensure `~/oss-projects` exists (`mkdir -p ~/oss-projects`) and clone/fork into `WORKSPACE_DIR` (see Step 3).
- All subsequent operations (analysis, edits, tests, PR) happen inside `WORKSPACE_DIR`.

## Step 2: Fetch the issue details
- Fetch the issue description:
  `gh issue view <issue_number> --repo <owner>/<repo>`
- Display the issue title, body, and labels to the user.
- Confirm: **"Shall I proceed to work on this issue? (yes/no)"**
- If no, stop.

## Step 2.5: Check for duplicate work and existing pull requests (globally)
- **Global duplicate detection** (works from any directory, at any depth):
  - Scan the whole global workspace for any checkout already working on this issue:
    `ls -d ~/oss-projects/*-issue-<issue_number> 2>/dev/null` and for each hit verify it references `<owner>/<repo>`.
  - Query GitHub for PRs that reference the issue:
    - `gh search prs "Closes #<issue_number>" "Fixes #<issue_number>" "Resolves #<issue_number>" --repo <owner>/<repo> --state open --json number,title,url,author,state`
    - Also search by the issue title: `gh search prs "<issue title>" --repo <owner>/<repo> --state open --json number,title,url`
- **Decision logic**:
  - If an **open PR already exists** for this issue anywhere: warn the user and do NOT create a new one automatically.
  - If `WORKSPACE_DIR` already contains commits/work for this issue, REUSE it rather than re-cloning or forking again.
  - If you find duplicate checkouts of the same issue in the workspace, use the canonical `WORKSPACE_DIR` and avoid creating another copy.
- Warn format when an open PR exists:
  ```
  Heads up! This issue already has an open pull request:
  https://github.com/<owner>/<repo>/pull/<number> - "<PR title>" by <author>
  ```
- Ask the user how to proceed: **"Would you like to (1) work on the issue anyway / coordinate, or (2) stop?"**
- If the user chooses to stop, end the workflow. If they proceed, continue.

## Step 3: Ensure the workspace clone (clone, fork, or reuse)
- If `WORKSPACE_DIR` already exists and is a git repo, **reuse it** and skip to Step 4. Reset it to a clean state on the appropriate base if needed (e.g. `git fetch upstream && git checkout <base>`), but do NOT delete other branches or unrelated work.
- If `WORKSPACE_DIR` does not exist (standalone `/oss-issue` use), create it and clone/fork:
  - **Check contribution rules first** (fetch from GitHub without cloning):
    - `curl -sL https://raw.githubusercontent.com/<owner>/<repo>/main/CONTRIBUTING.md | head -200`; if that fails try `/master/`.
    - Also check: `CODE_OF_CONDUCT.md`, `SECURITY.md`, `.github/PULL_REQUEST_TEMPLATE.md`, `.github/ISSUE_TEMPLATE/`, `DCO`, `CLA`.
    - Read the guide and extract: forking policy, branch naming, commit style, PR requirements (signed commits, linked issue, changelog, template), code style/lint tools, testing requirements, CLA/DCO, review process, labels/conventions.
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
- **Push based on how the repo was cloned**:
  - If you cloned the upstream directly (no fork): check permissions with `gh api repos/<owner>/<repo>/collaborators/<your-username>/permission | jq .permission`. If "admin"/"write", push to origin. If not, fork and push to fork.
  - If you already cloned your fork (from Step 3): `git push -u origin <current-branch>`
- Create the PR:
  `gh pr create --title "fix: ..." --body "Closes #<issue_number>.\n\n<brief description>" --base main`
  - If upstream uses a different default branch, target that.
  - Fill in any PR template if `gh` picks one up.
- **Apply contribution-guide metadata to the PR** (labels, reviewers, assignees) exactly as determined in Step 3. Note: as an external contributor you usually **cannot** set labels/reviewers/assignees on the upstream repo - only maintainers can. Attempt them anyway but **never fail the workflow** if they're denied; instead inform the user what was and wasn't applied.
  - **Labels**: If the contribution guide (Step 3) specified labels to add, apply them: `gh pr edit <pr-number> --add-label "label1,label2" --repo <owner>/<repo>`. Otherwise skip - do not invent labels.
  - **Reviewers**: If the contribution guide explicitly names reviewers, request them: `gh pr edit <pr-number> --add-reviewer <user1,user2> --repo <owner>/<repo>`. Otherwise rely on the repo's automatic mechanisms (e.g. `CODEOWNERS`, auto-assign bots) and do not guess reviewers.
  - **Assignees**: Assign the issue to yourself as the author (do not assign maintainers to open issues/PRs they triage): `gh issue edit <issue_number> --add-assignee @me --repo <owner>/<repo>`.
  - **Cross-link the PR**: ensure the PR body references the issue (e.g. `Closes #<issue_number>`) so GitHub links them; if the guide requires a changelog entry or a specific PR description format, honor it.
- **Verify the PR state** after creation: `gh pr view <pr-number> --repo <owner>/<repo> --json title,labels,reviewRequests,assignees,url`. Report any metadata you could and could not set, and why (e.g. "no permission", "labels not configured in the guide").
- Display the PR URL to the user.

## Critical rules
- Always pause and ask for user confirmation before any irreversible change (clone, commit, push, PR creation).
- **Never** work inside the user's current project directory - only inside `WORKSPACE_DIR` under `~/oss-projects`.
- **Never** duplicate an issue: reuse the deterministic workspace path and honor the existing-PR/duplicate checks in Step 2.5.
- Respect the project's existing code style and contribution guidelines.
- If any step fails, inform the user gracefully.
