# OSS Hunter

Slash command for AI coding agents to discover and fix real open-source issues with deep triage, project health scoring, and structured handoff.

Supported agents: [OpenCode](https://github.com/anomalyco/opencode) · [Claude Code](https://docs.anthropic.com/en/docs/claude-code) · [Codex CLI](https://github.com/openai/codex) · [Cursor](https://cursor.sh) · [Kimi Code](https://kimi.moonshot.cn)

## Quick install

```bash
curl -sL https://raw.githubusercontent.com/Fenomen-Alex/oss-hunter/main/install.sh | bash
```

Or install per agent below.

---

### Claude Code

**From marketplace:** `/plugin install oss-hunter@claude-plugins-official`

**From repo:** `/plugin install https://github.com/Fenomen-Alex/oss-hunter`

---

### OpenCode

```bash
mkdir -p ~/.config/opencode/commands
curl -sL https://raw.githubusercontent.com/Fenomen-Alex/oss-hunter/main/.opencode/plugins/oss-hunter.md -o ~/.config/opencode/commands/oss-hunter.md
curl -sL https://raw.githubusercontent.com/Fenomen-Alex/oss-hunter/main/.opencode/plugins/oss-issue.md -o ~/.config/opencode/commands/oss-issue.md
```
Restart.

---

### Codex CLI

**From marketplace:** `/plugins` search "oss-hunter"

**From repo:**
```bash
mkdir -p ~/.codex/commands
curl -sL https://raw.githubusercontent.com/Fenomen-Alex/oss-hunter/main/.codex-plugin/oss-hunter.md -o ~/.codex/commands/oss-hunter.md
curl -sL https://raw.githubusercontent.com/Fenomen-Alex/oss-hunter/main/.codex-plugin/oss-issue.md -o ~/.codex/commands/oss-issue.md
```

---

### Cursor

```
/add-plugin oss-hunter
```

---

### Kimi Code

**From marketplace:** `/plugins` > Marketplace > OSS Hunter

**From repo:**
```bash
mkdir -p ~/.kimi/commands
curl -sL https://raw.githubusercontent.com/Fenomen-Alex/oss-hunter/main/.kimi-plugin/commands/oss-hunter.md -o ~/.kimi/commands/oss-hunter.md
curl -sL https://raw.githubusercontent.com/Fenomen-Alex/oss-hunter/main/.kimi-plugin/commands/oss-issue.md -o ~/.kimi/commands/oss-issue.md
```

---

## Usage

Inside your agent chat, type:

```
# Phase 1: search for issues (clones to ~/oss-projects, then hands off to /oss-issue)
/oss-hunter react, typescript, tailwind --limit 10 --sort stars

# Phase 2: work from a specific issue URL (or point at an existing workspace clone)
/oss-issue https://github.com/vercel/next.js/issues/84616
/oss-issue https://github.com/vercel/next.js/issues/84616 ~/oss-projects/vercel-next.js-issue-84616
```

**Options for `/oss-hunter`:**
- `--limit N` - number of issues to show (default 5, max 25)
- `--sort updated` - sort by most recently updated (default; the cheapest and best actionability signal)
- `--sort stars` - sort by repo popularity/stars (optional; requires a few extra calls to enrich the final list)
- `--skills <list>` or `--stack <list>` - your tech stack/skills (e.g. `--skills react,redux,typescript,antd`). The plugin verifies repos actually use these technologies and saves your profile locally for future sessions

**Arguments for `/oss-issue`:**
- `<issue-url>` (required) - the GitHub issue to fix
- `<workspace-path>` (optional) - an already-prepared global workspace clone to reuse instead of re-cloning

## Prerequisites

- **Git**
- **GitHub CLI (`gh`)** - install from https://cli.github.com, then `gh auth login`
- **Node.js >= 18** - for most JS/TS projects

## How it works

OSS Hunter is a **two-phase** flow. Discovery and the actual coding work run in **separate sessions**, so the agent never gets confused by an overloaded context.

**Phase 1 — `/oss-hunter` (discover & handoff)**
1. You provide keywords and an optional limit
2. The agent searches for open issues matching your keywords across **12+ beginner-friendly labels** (`good first issue`, `help wanted`, `first-timers-only`, `up-for-grabs`, etc.) with **multi-signal parallel search** and a semantic fallback for unlabeled issues
3. The agent verifies each candidate repo actually uses your claimed skills before surfacing it
4. You pick an issue to work on
5. **Issue triage**: the agent reads the issue's **full discussion** and timeline, detects linked/open/merged PRs, assignees, maintainer engagement, ambiguity, and signals that the issue is claimed, already solved, or too complex, and gives a **RED / YELLOW / GREEN** verdict plus a **Readiness Score (0-5)** before you commit to it
6. **Project health pre-screen**: the agent evaluates the repository's stars, recent commit activity, CODE_OF_CONDUCT presence, and license before scoring
7. The agent clones the repository into a global workspace at `~/oss-projects/<owner>-<repo>-issue-<number>` (or reuses it if already present)
8. **Contribution guide analysis**: the agent parses the repository's contribution guide and extracts structured requirements (branch naming regex, commit style, lint/test commands, CLA/DCO)
9. **Handoff**: a structured JSON file is written to `~/oss-projects/.handoff/` containing the full triage verdict, project health, and parsed contribution guide. A fresh coding-agent session is opened directly on the cloned directory, passing the issue URL to `/oss-issue`

**Phase 2 — `/oss-issue` (fix & PR, run in the fresh session)**
8. The agent loads the structured handoff JSON and **short-circuits triage** — no re-fetching the full discussion unless used standalone
9. A fix plan is proposed for your review (with duplicate detection and lightweight triage confirmation)
10. After approval, the agent implements the fix and runs tests
11. The agent creates a pull request (honoring contribution guide: labels, reviewers, assignees)

> **Issue triage**: the plugin never trusts the title or labels alone. It inspects the issue's **full discussion**, timeline, and linked PRs to rule out issues that are already being handled or solved. It computes a **First-Step Readiness Score (0-5)** based on issue clarity, discussion maturity, project welcoming signals, setup cost, skill match, and claim risk. This keeps your contribution journey seamless and avoids dead-end work.

> **Efficiency**: the search uses **three parallel `gh search issues` calls** covering 12+ beginner-friendly labels, with a semantic fallback for unlabeled issues. It does **not** run the expensive "search each repo, then triage every issue" loop. The discussion triage runs only on the **one issue you select**, reads the **full discussion** (not just the last 10 comments), and inspects timeline events. When fixes come up, the triage/contribution context is passed via a **structured JSON handoff file** so `/oss-issue` doesn't re-fetch and re-parse the whole discussion.

> **Global workspace**: All cloned/forked repos live in `~/oss-projects/<owner>-<repo>-issue-<number>` — never inside your current project. Because the path is derived from the owner, repo, and issue number, the same issue always maps to the same directory. This gives **global deduplication** (no duplicate checkouts, from anywhere in the filesystem) and never nests a git repo inside your own project, so it can't mess with your IDE's version control.
>
> **Fresh session per issue**: The coding work happens in a new session opened directly on the clone, so the agent's context is clean and focused only on fixing that one issue. You can also run `/oss-issue <issue-url> <workspace-path>` manually to point at an existing workspace clone.

### Project Health Pre-Screen

Before scoring any issue, the plugin evaluates the target repository:

- **Stars / forks / open issues** ratio
- **Recent commit activity** (last commit date)
- **Community health files**: `CODE_OF_CONDUCT.md`, `SECURITY.md`
- **License** presence

This prevents you from investing time in repos with zero maintainer response, no community standards, or abandoned activity.

### First-Step Readiness Score

Every selected issue gets a score from **0.0 to 5.0** across six dimensions:

- **Issue clarity** (0-1): reproduction steps, acceptance criteria, code references
- **Discussion maturity** (0-1): maintainer engagement, ambiguity resolved, recent activity
- **Project welcoming** (0-1): CODE_OF_CONDUCT, PR review responsiveness, contributor diversity
- **Setup cost** (0-1): estimated time to get the repo running (1 = trivial, 0 = >30 min)
- **Skill match** (0-1): does the repo actually use your claimed skills?
- **Claim risk** (0-1): are multiple people already expressing interest?

A score below 2.5 bumps the verdict toward caution. You see the breakdown before cloning anything.

### Structured Handoff

Instead of copy-pasting context between sessions, `/oss-hunter` writes a **JSON handoff file** at `~/oss-projects/.handoff/<owner>-<repo>-issue-<number>.json`. This file contains:

- Issue metadata, verdict, and readiness score
- Project health summary
- Parsed contribution guide (branch naming, commit style, CLA/DCO, test commands)
- Workspace path

`/oss-issue` loads this file and short-circuits its own triage, so you never re-fetch and re-parse the whole discussion.

### Learning Memory

The plugin persists a local history at `~/.config/oss-hunter/history.json` of every issue you explored, its verdict, and the outcome (skipped / started / completed / abandoned). Over time this:

- Avoids re-surfacing issues you already tried
- Ranks keywords by your past success rate
- Helps the agent give better recommendations based on your actual contribution patterns

### Skill Verification

When you pass `--skills react,typescript`, the plugin doesn't just use those as search keywords. It cheaply verifies that the target repo actually uses those technologies (by checking `package.json`, `go.mod`, `Cargo.toml`, `pyproject.toml`, etc.) before surfacing the issue. A "React" issue in a repo that hasn't touched React in 3 years gets demoted or discarded.

### Rate-Limit Awareness

Before any batch of `gh` calls, the plugin checks your GitHub CLI quota (`gh api rate_limit`). If remaining calls drop below 10, it warns you and suggests retrying later or narrowing your search — so you don't start a 10-step workflow only to hit a 403 halfway through.

### Duplicate Detection

Before recommending an issue, the plugin runs a quick scan for duplicates and superseding issues in the same repo. If a closed duplicate exists, you're warned before wasting time on a solved problem.

### Contribution Guide Analysis

When working on an issue, the plugin automatically analyzes the target repository's contribution guide and provides:

- **Structured parsing**: extracts forking policy, branch naming convention (as regex/template if explicit), commit message style, PR requirements, code style/lint tools, testing requirements, CLA/DCO, review process, and labels/conventions from `CONTRIBUTING.md`, PR templates, `CODEOWNERS`, and config files
- **Contribution requirements summary**: presented as a deterministic checklist, not LLM-generated guesses
- **Potential improvements**: Suggestions for improving the repository's contribution process

This ensures you follow the project's conventions and helps maintainers improve their contribution guidelines.

### Pull request creation

After the fix is implemented and tested, the plugin creates the pull request and then follows the contribution guide to apply PR metadata where possible:

- **Labels**: applies labels only if the contribution guide specifies them (never invents labels)
- **Reviewers**: requests reviewers if the guide names them; otherwise relies on the repo's automatic mechanisms (e.g. `CODEOWNERS`, auto-assign bots)
- **Assignees**: assigns the issue to you as the author
- **Cross-linking**: ensures the PR body references the issue (e.g. `Closes #N`)

> As an external contributor, you usually can't set labels/reviewers/assignees on the upstream repo (only maintainers can). The plugin attempts them and reports which were applied and which were denied, without failing the workflow.

> **Rate-limit aware**: the plugin checks your GitHub CLI quota before PR creation and warns if calls are running low.

## Directory structure

```
oss-hunter/
├── install.sh                    # Auto-install script
├── .opencode/                    # OpenCode plugin
│   ├── INSTALL.md
│   ├── plugins/oss-hunter.md
│   └── plugins/oss-issue.md
├── .claude-plugin/               # Claude Code plugin
│   ├── plugin.json
│   ├── marketplace.json
│   └── commands/
│       ├── oss-hunter.md
│       └── oss-issue.md
├── .cursor-plugin/               # Cursor plugin
│   └── plugin.json
├── .codex-plugin/                # Codex CLI plugin
│   ├── plugin.json
│   ├── oss-hunter.md
│   └── oss-issue.md
└── .kimi-plugin/                 # Kimi Code plugin
    ├── plugin.json
    └── commands/
        ├── oss-hunter.md
        └── oss-issue.md
```

## Plugin marketplaces

OSS Hunter is designed to be listed on official plugin marketplaces:

- **Claude Code marketplace** - install via `/plugin install oss-hunter@claude-plugins-official`
- **Codex marketplace** - install via `/plugins` search in Codex CLI
- **Cursor marketplace** - install via `/add-plugin oss-hunter`
- **Kimi Code marketplace** - install via `/plugins` in Kimi Code's plugin manager

To publish on these marketplaces, see each platform's submission guide:
- [Claude Code plugin publishing](https://docs.anthropic.com/en/docs/claude-code/plugins)
- [Codex plugin publishing](https://github.com/openai/plugins)
- [Cursor extension marketplace](https://docs.cursor.com/extensions/creating-extensions)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT
