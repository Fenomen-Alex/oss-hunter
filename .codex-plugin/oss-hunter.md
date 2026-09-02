<!-- Command: oss-hunter -->
<!-- Description: Find and fix open source issues. Sort by repo stars (default) or recently updated. Supports --skills/--stack and personalized search. -->

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
- Define a **Skill Profile** (representing the user's skillset and framework preferences) to filter and focus search results.
- Resolve the Skill Profile as follows:
  1. **Direct parameter**: If `--skills` or `--stack` was provided in Step 0, parse it as a list and use it as the active Skill Profile.
  2. **Global Config**: If no skills are explicitly provided, check if a global profile exists at `~/.config/oss-hunter/config.json`. If it does, load the saved skills as the active Skill Profile.
  3. **Interactive Prompt**: If no skills/keywords are specified and no global profile exists:
     - Ask the user: *"What is your preferred tech stack/skills? (e.g. react, typescript, redux, antd)"*
     - Use the user's response as the active Skill Profile.
     - Ask the user: *"Would you like to save this as your default profile in ~/.config/oss-hunter/config.json? (yes/no)"*
     - If they agree, create the directory `~/.config/oss-hunter/` if needed, and write the profile in JSON format: `{"skills": ["react", "typescript", ...], "updatedAt": "..."}`.

## Step 1: Understand the global workspace model
- **Critical**: The plugin NEVER clones into the user's current project/repository, and it NEVER nests git repos inside other git repos. That confuses the user's IDE (multiple VCS roots) and confuses the agent. All cloned/forked repos live in a single **global workspace** in the home directory.
- The global workspace root is `$HOME/oss-projects` (i.e. `~/oss-projects`).
- Each issue gets a **deterministic, globally-unique directory**: `~/oss-projects/<owner>-<repo>-issue-<issue-number>`.
  - Because this path encodes the owner, repo, and issue number, the same issue always maps to the same directory **no matter where you invoke the command from or how deep you are in the filesystem**. This is the global deduplication mechanism.
- You will only **find, select, clone, and hand off** in this command. The actual code analysis, fix, and PR creation happen in a **separate, fresh coding-agent session** run by `/oss-issue` directly inside the cloned directory.

## Step 2: Find open issues by keywords (one efficient search)
- Use the **keywords** and active **Skill Profile** to find open, beginner-friendly issues.
- If no keywords were explicitly provided but a Skill Profile is active, use the terms from the Skill Profile as the search keywords.
- **This step is a SINGLE GitHub search call** - do NOT use a "find repos, then search each repo" loop, which burns dozens of API calls and quota. One `gh search issues` call already filters `state:open`, labels, and unassigned, and returns cheap prescreen fields inline.
- Run **one** search:
  ```
  gh search issues <keywords...> --label "good first issue" --label "help wanted" --state open --no-assignee --sort updated --order desc --limit <limit> --json number,title,repository,labels,assignees,updatedAt,commentsCount,url
  ```
  - `<keywords...>` = the keywords and skill terms (e.g. `react typescript redux`).
  - `--no-assignee`: excludes issues already claimed by someone - a free, API-level actionability filter. (Still verify linked PRs in triage, since an unassigned issue can still have an open PR.)
  - `--label "good first issue" --label "help wanted"`: the beginner-friendly markers.
  - `--sort updated --order desc`: freshest first - recently updated issues are much more likely to be still-open, actionable, and maintained.
  - The returned `updatedAt`, `commentsCount`, and `assignees` fields let you rank and filter without any extra calls:
    - Prefer issues updated within the last ~6 months (older = more likely stale).
    - `assignees` should be empty (enforced by `--no-assignee`, but verify).
    - Treat very high `commentsCount` (>50) as a caution: could indicate an unresolved flamewar/discussion, not a clean task.
- **`--sort stars` (optional enrichment)**: GitHub cannot star-sort issues in one call. So if the user explicitly requested `--sort stars`:
  - Run the single issue search above (limit = 2x desired), then for **only the final candidates you intend to display** (a handful, <= limit), fetch their repo star counts: `gh repo view <owner>/<repo> --json stargazerCount,nameWithOwner`. Re-sort by stars locally. This is a few calls on the final list, NOT per-repo searches.
- **Relevancy ranking**:
  - Default (`updated`): order by freshness (recency of `updatedAt`), then prefer well-known/reputable repos; discard suspicious/empty/no-activity repos (check `repository` and, if cheap, the repo description/stars).
  - `stars`: order by repo popularity.
- Collect up to **`limit`** distinct issues. Each entry must include:
  - Repository full name (e.g. `expressjs/express`) with star count (if known from enrichment)
  - Issue number and title
  - Issue URL
  - A short snippet of the issue description (can be omitted if not cheaply available - the title and repo are usually enough for selection)

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
- Validate the selection and note the chosen repository, issue number, and issue URL.

## Step 3.5: Triage the issue (actionability screen)
- **Goal**: never waste the user's first-contribution effort on an issue that is already solved, already claimed, or not actually beginner-friendly. Before recommending or cloning, deeply inspect the issue **including its discussion**, and produce a clear verdict.
- Compute the canonical workspace path: `WORKSPACE_DIR=~/oss-projects/<owner>-<repo>-issue-<issue-number>`.
- **Be cheap**: reuse what Step 2 already returned inline (`assignees`, `labels`, `updatedAt`, `commentsCount`). Only fetch the extra data that the search cannot provide, and **do it once for the single selected issue** (never for every candidate).
- **Fetch linked PRs and the discussion (one call):**
  - `gh issue view <issue-number> --repo <owner>/<repo> --json state,assignees,labels,comments,closedByPullRequestsReferences`
  - **`closedByPullRequestsReferences`**: PRs GitHub considers to address this issue. For each, check its current state compactly (usually 0-2 PRs):
    `gh pr view <pr-number> --repo <owner>/<repo> --json state,mergedAt,isDraft`
  - **`comments`**: read the discussion, but stay bounded - examine at most the **last ~10 comments** plus the title/body. Signals to detect (via keywords, not a full deep read):
    - Someone claiming it ("I'll work on this", "beginning to work on a fix", "assigned to me")
    - An already-opened PR ("I opened a PR", "dev work is complete", "PR awaiting review")
    - A maintainer downgrading it ("I removed the label `good first issue`", "requires a fix at a higher level", "too complex", "out of scope")
    - Staleness ("Is anyone still working on this?", no activity in months)
    - Ambiguity: the body is a question/discussion rather than a concrete, scoped task
  - If the user already provided the triage result from a prior `/oss-hunter` run (e.g. via handoff note), you may **skip re-fetching** and reuse it.
- **Evaluate against these rules and assign a verdict**:
  - **RED - do NOT recommend** (stop, pick another issue):
    - A linked PR exists and is **open** (someone is already working on it) → warn with PR URL.
    - A linked PR exists and is **merged** (the issue is effectively already solved) → warn with merged PR URL.
    - Someone is **assigned** or explicitly claimed it in the comments.
    - The body is an open-ended **question/feature-discussion** with no clear, actionable task.
  - **YELLOW - caution** (surface the reason, let the user decide):
    - The `good first issue` / `help wanted` label was **removed** or never present, or a maintainer noted it is not beginner-friendly / under-specified.
    - No assignee but multiple people asked to work on it / stale with no maintainer response.
    - Only an open PR exists but it looks abandoned/stale (e.g. unmerged for a long time with no activity) - the maintainers may still welcome a competing PR.
  - **GREEN - safe to proceed**: open, unassigned, no linked PR, clear scoped task, no negative signals in the discussion.
- **Present the verdict clearly** before any clone:
  ```
  Issue Triage for <owner>/<repo>#<issue-number>:
  Verdict: 🟢 GREEN / 🟡 YELLOW / 🔴 RED
  • Linked PR: none | #<n> (open|merged) - URL
  • Assignee: none | <user>
  • good first issue: present | removed | absent
  • Discussion signals: <summary of what you found in the comments>
  • Actionability: <why it is or is not a good first contribution>
  ```
  (Use a 🟢/🟡/🔴 marker in text, and an ASCII "GREEN/YELLOW/RED" word so it is unambiguous.)
- **Decision logic**:
  - If **RED**, warn clearly and recommend picking a different issue (loop back to Step 3). If the user insists, proceed with their explicit consent.
  - If **YELLOW**, surface the concern and ask the user to confirm they want to proceed.
  - If **GREEN**, proceed.
  - Note: the verdict explicitly incorporates the discussion, so a "good first issue" that was removed/complexified in the comments is caught here - never trust the label alone.
- Also perform **global duplicate detection**:
  - If `WORKSPACE_DIR` already exists and contains a git repo (`.git`): it was already checked out before. Inspect `git -C "$WORKSPACE_DIR" log --oneline -5` and `branch -a`; REUSE it rather than re-cloning.
  - Scan the whole global workspace: `ls -d ~/oss-projects/*-issue-<issue-number> 2>/dev/null` and verify each hit references `<owner>/<repo>`; point the user to the canonical `WORKSPACE_DIR` and avoid duplicate copies.

## Step 4: Ensure the workspace clone (clone or reuse)
- Ensure the global workspace root exists: `mkdir -p ~/oss-projects`.
- If `WORKSPACE_DIR` already exists and is a git repo, **reuse it** (do not re-clone). Skip straight to the contribution analysis below, then to the handoff.
- Otherwise, create it and clone/fork into it:
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
    - Read the contribution guide carefully. Extract (to be passed to `/oss-issue` in the handoff):
      - **Forking policy**: does it require forking? (almost always yes for external contributors)
      - **Branch naming convention**: e.g. `fix/issue-1234`, `feature/...`, `<username>/fix-...`
      - **Commit message style**: conventional commits? `fix: ...` / `feat: ...`? Must reference issue?
      - **PR requirements**: signed commits? linked issue? changelog entry? PR template?
      - **Code style**: linter/formatter to run? (e.g. `npm run lint`, `prettier`, `black`, `gofmt`)
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
    - If you have push access OR the repo allows direct branches: `gh repo clone <owner/repo> "$WORKSPACE_DIR"`.
    - If forking is required (default): first fork via `gh repo fork <owner/repo> --clone=false`, then clone your fork into the workspace:
      `gh repo clone <your-username>/<repo> "$WORKSPACE_DIR"` (or `git clone https://github.com/<your-username>/<repo>.git "$WORKSPACE_DIR"`)
    - After cloning your fork, set the upstream remote: `git -C "$WORKSPACE_DIR" remote add upstream https://github.com/<owner>/<repo>.git`
    - Create a new branch following the repo's naming convention:
      `git -C "$WORKSPACE_DIR" checkout -b <branch-name>`
- Confirm the workspace is prepared and note the path.

## Step 5: Hand off to a fresh coding-agent session via `/oss-issue`
- **Do NOT analyze the codebase, write fixes, or create the PR in this session.** Doing so mixes contexts and confuses the agent. Instead, start a **fresh coding-agent session opened directly on the cloned directory** and pass the issue to `/oss-issue`.
- Present the handoff:
  ```
  Workspace ready: ~/oss-projects/<owner>-<repo>-issue-<issue-number>
  Issue: <issue-url>

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
- **Pass along the context**: include the **triage verdict** from Step 3.5 (RED/YELLOW/GREEN + linked-PR state + assignee + any discussion red flags) and the **contribution-guide summary** from Step 4 (forking policy, branch naming, commit style, CLA/DCO, labels, PR template) so `/oss-issue` can short-circuit its own triage and honor conventions **without re-fetching and re-parsing the whole discussion**. Include them in the `/oss-issue` prompt or as a short note to the user (e.g. in the generated handoff command).

## Critical rules
- Always pause and ask for user confirmation before any irreversible change (fork, clone, commit, push, PR creation).
- **Never** clone, create files, or modify anything inside the user's current project directory. All work happens under `~/oss-projects`.
- **Never** duplicate an issue: the deterministic workspace path and the existing-PR/duplicate checks in Step 3.5 prevent this.
- Do not analyze, fix, or open a PR from this discovery command - that is the job of the fresh `/oss-issue` session.
- If any step fails (e.g. search returns no results), inform the user gracefully and suggest trying different keywords.
