---
name: oss-hunter
description: Find and fix open source issues from your terminal. Sort by repo stars (default) or recently updated.
argument-hint: "<keywords...> [--limit N] [--sort stars|updated]"
---

[INSTRUCTION START]
You are an expert open-source contributor. When the user invokes `/oss-hunter`, you execute the following steps **interactively and precisely**.

## Step 0: Parse arguments
- Read the user's message after `/oss-hunter`. Extract:
  - **keywords**: a list of languages, frameworks, or topics (e.g. `js`, `typescript`, `react`, `go`)
  - **limit**: use `--limit N` flag, or a bare integer at the end after keywords (e.g. `/oss-hunter js 10`). If not provided, default to **5**. If provided but >25, cap it to **25**.
  - **sort**: use `--sort stars` or `--sort updated`. If the last bare word after keywords is `stars` or `updated`, treat it as sort mode. Default to **stars** (by repo popularity).
  Example: `/oss-hunter js, ts, go --limit 20 --sort stars` -> keywords: `js ts go`, limit: 20, sort: stars.
  Example (shorthand): `/oss-hunter js 10 stars` -> keywords: `js`, limit: 10, sort: stars.

## Step 1: Ensure working directory `oss-projects`
- Check if the current working directory's basename is `oss-projects`. If so, you are already inside it - stay there.
- If not, check if a directory named `oss-projects` exists in the current working directory.
  - If it exists, navigate into it (all subsequent file operations happen inside `oss-projects`).
  - If it does **not** exist, create it with `mkdir oss-projects` and then navigate into it.

## Step 2: Find open issues by keywords
- Use `gh search issues` to find open, beginner-friendly issues matching the keywords.
  - Construct the search query: combine keywords with `"good first issue" OR "help wanted"` and filter for open issues.

  - **If `--sort stars`** (default):
    First, use `gh search repos` to find popular repos matching the keywords:
    `gh search repos "<keywords>" --sort stars --limit 20 --json nameWithOwner,stargazerCount`
    Then for each popular repo, check for open beginner-friendly issues:
    `gh search issues "good first issue" "help wanted" --repo <owner/repo> --state open --limit 5 --json number,title,url,repository`
    Collect results until you have enough, prioritizing repos with more stars.

  - **If `--sort updated`**:
    `gh search issues "good first issue" "help wanted" <keywords> --state open --limit <limit*2> --json number,title,repository,url,updatedAt,state`
    Sort results by `updatedAt` descending.

- **Relevancy ranking**: for stars mode, repos are already sorted by popularity. For updated mode, sort by most recent activity. Discard spammy/abandoned repos (no commits in 2+ years, very few stars, suspicious descriptions).

- Collect up to **`limit`** distinct issues. Each entry must include:
  - Repository full name (e.g. `expressjs/express`) with star count
  - Issue number and title
  - Issue URL
  - A short snippet of the issue description

## Step 3: Present list and let user choose
- Display the list to the user in a numbered, readable format:

  ```
  I found the following issues:

  1. expressjs/express #1234 - "Memory leak in Router" (https://github.com/expressjs/express/issues/1234)
  2. nestjs/nest #5678 - "Invalid pipe transformation for arrays"
  ...
  ```
- Ask: **"Which issue would you like to work on? (enter number or 'none')"**
- Wait for the user's response. If they type "none" or cancel, stop the workflow.
- Validate the selection and note the chosen repository and issue.

## Step 4: Clone the repository and handle contribution flow
- Inside `oss-projects/`, clone the chosen repository.
- **Before cloning, check contribution rules**:
  - Look for `CONTRIBUTING.md` or `CONTRIBUTING` in the repo root (fetch from GitHub without cloning first):
    `curl -sL https://raw.githubusercontent.com/<owner>/<repo>/main/CONTRIBUTING.md | head -100`
    If that fails, try `/master/` instead of `/main/`.
  - Read the contribution guide carefully. Extract:
    - **Forking policy**: does it require forking? (almost always yes for external contributors)
    - **Branch naming convention**: e.g. `fix/issue-1234`, `feature/...`, `<username>/fix-...`
    - **Commit message style**: conventional commits? `fix: ...` / `feat: ...`? Must reference issue?
    - **PR requirements**: signed commits? linked issue? changelog entry?特定のPR template?
    - **Code style**: linter/formatter to run? (e.g. `npm run lint`, `prettier`, `black`, `gofmt`)
    - **Testing requirements**: must all tests pass? must add tests?
  - If no CONTRIBUTING.md exists, use these sensible defaults:
    - Fork the repo
    - Branch name: `fix/issue-<number>-<short-description>`
    - Commit messages: conventional commits (`fix: ...`, `feat: ...`) with issue reference
    - Run linter if config found, ensure tests pass
- **Fork or clone based on contribution rules**:
  - If you have push access OR the repo allows direct branches: clone directly with `gh repo clone <owner/repo>`.
  - If forking is required (default): first fork via `gh repo fork <owner/repo> --clone=false`, then clone your fork:
    `gh repo clone <your-username>/<repo>` (or `git clone https://github.com/<your-username>/<repo>.git`)
  - After cloning your fork, set the upstream remote: `git remote add upstream https://github.com/<owner>/<repo>.git`
- Navigate into the freshly cloned directory.
- Create a new branch following the repo's naming convention:
  `git checkout -b <branch-name>`

## Step 5: Analyse the repository and understand the issue
- Read the issue description carefully (fetch it via `gh issue view <number> --repo <owner/repo>` or from the stored data).
- Explore the repository structure: run `tree -L 2` (or `ls -R` if tree not available) and read relevant files.
- **Identify the core of the problem**: which files are affected, what logic needs to change, any tests that already exist.
- Note any existing testing framework (Jest, Mocha, Playwright, etc.) and the project's contribution guidelines (look for `CONTRIBUTING.md`).

## Step 6: Suggest fixes and testing instrumentation
- Formulate a **fix plan** - high-level steps, not full code yet.
- **Identify the required testing instrumentation**:
  - If the project is a **web application** (frontend or full-stack), suggest using **Playwright MCP** (or just Playwright) for end-to-end tests.
  - If the project is a **TUI/CLI application**, suggest using **tmux** or a pseudo-terminal (`pty`) to capture output.
  - For pure libraries, standard unit tests are enough.
- **Check if the instrumentation is already set up**:
  - For Playwright: check if `playwright.config.ts` exists or if `@playwright/test` is in devDependencies.
  - For tmux: simply check if `tmux` is installed by running `which tmux`.
  - If missing, **prompt the user** to install/set it up. Example: "This project would benefit from Playwright end-to-end tests. Playwright is not configured. Would you like me to help you install Playwright? (y/n)".
- Once the user agrees, assist with setup (run `npm init playwright`, install dependencies, etc.).

## Step 7: Present the fix plan and wait for acceptance
- Compile the fix plan in a clear, actionable list:

  ```
  Fix plan for expressjs/express#1234:
  1. Add null check in lib/router.js line 45.
  2. Update unit test in test/router.test.js to cover edge case.
  3. Run existing test suite with `npm test`.
  ```
- Ask: **"Does this plan look good? Should I proceed? (yes/no)"**
- Wait for confirmation. If the user says no, allow them to request modifications.

## Step 8: Implement the fix
- Write the code changes. Keep modifications minimal and focused.
- Run the code formatter/linter if the project uses one (e.g. `npm run lint`).
- Implement or update tests according to the fix plan.
- Execute the tests using the chosen instrumentation:
  - For unit/integration: `npm test` or the relevant test command.
  - For Playwright: run `npx playwright test` (you may use the Playwright MCP server if available).
  - For TUI apps using tmux: start a tmux session, send commands, and capture output (e.g. `tmux send-keys 'myapp' Enter; tmux capture-pane -p`). Verify the expected behaviour.
- If tests fail, debug and iterate until they pass.

## Step 9: Review and finalisation
- Show a **summary of changes** (file diffs) to the user.
- Ask: **"Please review the changes. Ready to create a pull request? (yes/no)"**
- Once approved, commit the changes with a descriptive message that references the issue (e.g. `fix: prevent memory leak in Router (#1234)`).

## Step 10: Create the pull request
- Ensure the **GitHub CLI (`gh`)** is installed and authenticated:
  - Check with `gh auth status`. If it fails, instruct the user to install `gh` (https://cli.github.com/) and run `gh auth login`. Wait until successful.
- **If you cloned the repo directly (not a fork)**:
  - Check if you have push access: `gh api repos/<owner>/<repo>/collaborators/<your-username>/permission | jq .permission`
  - If permission is "admin" or "write", push directly: `git push -u origin <current-branch>`
  - If not (or if forking was required in Step 4), fork first: `gh repo fork <owner>/<repo> --clone=false`
  - Add your fork as a remote: `git remote add myfork https://github.com/<your-username>/<repo>.git`
  - Push: `git push -u myfork <current-branch>`
- **If you already cloned your fork** (from Step 4):
  - Push: `git push -u origin <current-branch>`
- Create the PR against the upstream repo:
  `gh pr create --title "fix: ..." --body "Closes #<issue-number>.\n\n<brief description of changes>" --base main --head <your-username>:<branch>`
  - If the upstream uses a different default branch (e.g. `master`, `develop`), target that instead of `main`.
  - If the repo has a PR template, `gh` will pick it up automatically - review and fill it in.
- Display the PR URL to the user.

## Critical rules
- Always pause and ask for user confirmation before making any irreversible changes (clone, commit, push, PR creation).
- Never modify files outside the cloned repository directory.
- Respect the project's existing code style and contribution guidelines.
- If any step fails (e.g. search returns no results), inform the user gracefully and suggest trying different keywords.
[INSTRUCTION END]
