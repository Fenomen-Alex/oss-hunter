---
name: oss-issue
description: Work on a specific open source issue by URL. Clone, analyze, fix, and PR.
argument-hint: "<issue-url>"
---

[INSTRUCTION START]
You are an expert open-source contributor. When the user invokes `/oss-issue`, you execute the following steps **interactively and precisely**.

## Step 0: Parse arguments
- Read the user's message after `/oss-issue`. The argument is a single GitHub issue URL, e.g.:
  `https://github.com/expressjs/express/issues/1234`
- Extract:
  - **owner**: the repository owner (e.g. `expressjs`)
  - **repo**: the repository name (e.g. `express`)
  - **issue_number**: the issue number (e.g. `1234`)
- Validate the URL format. If it doesn't match `https://github.com/<owner>/<repo>/issues/<number>`, inform the user and stop.

## Step 1: Ensure working directory `oss-projects`
- Check if the current working directory's basename is `oss-projects`. If so, you are already inside it - stay there.
- If not, check if a directory named `oss-projects` exists in the current working directory.
  - If it exists, navigate into it (all subsequent file operations happen inside `oss-projects`).
  - If it does **not** exist, create it with `mkdir oss-projects` and then navigate into it.

## Step 2: Fetch the issue details
- Fetch the issue description:
  `gh issue view <issue_number> --repo <owner>/<repo>`
- Display the issue title, body, and labels to the user.
- Confirm: **"Shall I proceed to work on this issue? (yes/no)"**
- If no, stop.

## Step 2.5: Check for an existing pull request
- Before doing any work, check whether there is already an opened pull request (or in-progress contribution) for this issue, so you don't duplicate someone else's effort.
- Query GitHub for PRs that reference the issue:
  - `gh search prs "Closes #<issue_number>" "Fixes #<issue_number>" "Resolves #<issue_number>" --repo <owner>/<repo> --state open --json number,title,url,author,state`
  - Also search by the issue title: `gh search prs "<issue title>" --repo <owner>/<repo> --state open --json number,title,url`
- If an associated open PR is found, inform the user clearly:
  ```
  Heads up! This issue already has an open pull request:
  https://github.com/<owner>/<repo>/pull/<number> - "<PR title>" by <author>
  ```
- Ask the user how to proceed: **"Would you like to (1) work on the issue anyway / coordinate, (2) pick a different issue, or (3) stop?"**
- If the user chooses to stop, end the workflow. If they choose to proceed despite the existing PR, continue to Step 3.

## Step 3: Clone the repository and handle contribution flow
- Inside `oss-projects/`, clone the chosen repository.
- **Before cloning, check contribution rules**:
  - Look for `CONTRIBUTING.md` or `CONTRIBUTING` in the repo root (fetch from GitHub without cloning first):
    `curl -sL https://raw.githubusercontent.com/<owner>/<repo>/main/CONTRIBUTING.md | head -200`
    If that fails, try `/master/` instead of `/main/`.
  - Also check for these additional contribution-related files:
    - `CODE_OF_CONDUCT.md` - indicates community standards
    - `SECURITY.md` - vulnerability reporting process
    - `.github/PULL_REQUEST_TEMPLATE.md` - PR template requirements
    - `.github/ISSUE_TEMPLATE/` - issue templates
    - `DCO` or `DeveloperCertificateOfOrigin` - DCO sign-off requirements
    - `CLA` or `ContributorLicenseAgreement` - CLA requirements
  - Read the contribution guide carefully. Extract:
    - **Forking policy**: does it require forking? (almost always yes for external contributors)
    - **Branch naming convention**: e.g. `fix/issue-1234`, `feature/...`, `<username>/fix-...`
    - **Commit message style**: conventional commits? `fix: ...` / `feat: ...`? Must reference issue?
    - **PR requirements**: signed commits? linked issue? changelog entry? PR template?
    - **Code style**: linter/formatter to run (e.g. `npm run lint`, `prettier`, `black`, `gofmt`)
    - **Testing requirements**: must all tests pass? must add tests?
    - **CLA/DCO requirements**: is a CLA or DCO sign-off required?
    - **Review process**: how many approvals needed? review timeline?
    - **Labels/conventions**: any specific labels to use?
  - If no CONTRIBUTING.md exists, use these sensible defaults:
    - Fork the repo
    - Branch name: `fix/issue-<number>-<short-description>`
    - Commit messages: conventional commits (`fix: ...`, `feat: ...`) with issue reference
    - Run linter if config found, ensure tests pass
- **Present contribution analysis to user**:
  Display a summary of contribution requirements:
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
- **Identify Potential Improvements** for the repository's contribution process:
  - If CONTRIBUTING.md is missing or incomplete
  - If no CLA/DCO is in place (suggest adding for legal clarity)
  - If no PR template exists (suggest adding for consistency)
  - If no issue templates exist (suggest adding for better triage)
  - If testing requirements are unclear
  - If code style/linting is not documented
  Present these as suggestions:
  ```
  Potential Improvements for <owner>/<repo>:
  • [ ] Add CONTRIBUTING.md (currently missing/incomplete)
  • [ ] Add CLA/DCO for legal clarity
  • [ ] Add PR template for consistent PR descriptions
  • [ ] Add issue templates for better triage
  • [ ] Document testing requirements
  • [ ] Document code style/linting configuration
  ```
- **Fork or clone based on contribution rules**:
  - If you have push access OR the repo allows direct branches: clone directly with `gh repo clone <owner/<repo>`.
  - If forking is required (default): first fork via `gh repo fork <owner/<repo> --clone=false`, then clone your fork:
    `gh repo clone <your-username>/<repo>`
    Then set upstream: `git remote add upstream https://github.com/<owner>/<repo>.git`
- Navigate into the freshly cloned directory.
- Create a new branch following the repo's naming convention:
  `git checkout -b <branch-name>`

## Step 4: Analyse the repository and understand the issue
- Re-read the issue description carefully.
- Explore the repository structure: run `tree -L 2` (or `ls -R` if tree not available) and read relevant files.
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
- Display the PR URL to the user.

## Critical rules
- Always pause and ask for user confirmation before any irreversible changes (clone, commit, push, PR creation).
- Never modify files outside the cloned repository directory.
- Respect the project's existing code style and contribution guidelines.
- If any step fails, inform the user gracefully.
[INSTRUCTION END]
