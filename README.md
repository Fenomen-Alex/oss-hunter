# OSS Hunter

Slash command for AI coding agents to discover and fix real open-source issues.

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
2. The agent searches for open issues matching your keywords
3. You pick an issue to work on
4. **Issue triage**: the agent reads the issue's full discussion and timeline, detects linked/open/merged PRs, assignees, and signals that the issue is claimed, already solved, or too complex (e.g. a `good first issue` label that was removed), and gives a **RED / YELLOW / GREEN** verdict before you commit to it
5. The agent clones the repository into a global workspace at `~/oss-projects/<owner>-<repo>-issue-<number>` (or reuses it if already present)
6. **Contribution guide analysis**: the agent summarizes the repository's contribution requirements
7. **Handoff**: a fresh coding-agent session is opened directly on the cloned directory, passing the issue URL to `/oss-issue`

**Phase 2 — `/oss-issue` (fix & PR, run in the fresh session)**
8. A fix plan is proposed for your review (after re-running the issue triage)
9. After approval, the agent implements the fix and runs tests
10. The agent creates a pull request (honoring contribution guide: labels, reviewers, assignees)

> **Issue triage**: the plugin never trusts the title or labels alone. It inspects the issue's discussion and timeline to rule out issues that are already being handled or solved (open/merged linked PRs, an assignee) and to catch issues that are actually complex despite a `good first issue` label (e.g. a maintainer comment removing the label). This keeps your contribution journey seamless and avoids dead-end work.

> **Efficiency**: the search is a single `gh search issues` call - it filters `state:open`, the beginner-friendly labels, and unassigned issues (`--no-assignee`) at the API level, and returns freshness/comment/assignee signals inline. It does **not** run the expensive "search each repo, then triage every issue" loop, and the discussion triage runs only on the **one issue you select**, bounded to the last ~10 comments. When fixes come up the triage/contribution context is passed forward so `/oss-issue` doesn't re-fetch and re-parse the whole discussion.

> **Global workspace**: All cloned/forked repos live in `~/oss-projects/<owner>-<repo>-issue-<number>` — never inside your current project. Because the path is derived from the owner, repo, and issue number, the same issue always maps to the same directory. This gives **global deduplication** (no duplicate checkouts, from anywhere in the filesystem) and never nests a git repo inside your own project, so it can't mess with your IDE's version control.
>
> **Fresh session per issue**: The coding work happens in a new session opened directly on the clone, so the agent's context is clean and focused only on fixing that one issue. You can also run `/oss-issue <issue-url> <workspace-path>` manually to point at an existing workspace clone.

### Contribution Guide Analysis

When working on an issue, the plugin automatically analyzes the target repository's contribution guide and provides:

- **Contribution requirements summary**: Forking policy, branch naming, commit style, CLA/DCO, PR template, code style, testing requirements
- **Potential improvements**: Suggestions for improving the repository's contribution process

This ensures you follow the project's conventions and helps maintainers improve their contribution guidelines.

### Pull request creation

After the fix is implemented and tested, the plugin creates the pull request and then follows the contribution guide to apply PR metadata where possible:

- **Labels**: applies labels only if the contribution guide specifies them (never invents labels)
- **Reviewers**: requests reviewers if the guide names them; otherwise relies on the repo's automatic mechanisms (e.g. `CODEOWNERS`, auto-assign bots)
- **Assignees**: assigns the issue to you as the author
- **Cross-linking**: ensures the PR body references the issue (e.g. `Closes #N`)

> As an external contributor, you usually can't set labels/reviewers/assignees on the upstream repo (only maintainers can). The plugin attempts them and reports which were applied and which were denied, without failing the workflow.

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
