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
```
Restart.

---

### Codex CLI

**From marketplace:** `/plugins` search "oss-hunter"

**From repo:**
```bash
mkdir -p ~/.codex/commands
curl -sL https://raw.githubusercontent.com/Fenomen-Alex/oss-hunter/main/.codex-plugin/oss-hunter.md -o ~/.codex/commands/oss-hunter.md
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
```

---

## Usage

Inside your agent chat, type:

```
/oss-hunter react, typescript, tailwind --limit 10 --sort stars
```

The agent will guide you through finding, fixing, and PR-ing a real open-source issue.

**Options:**
- `--limit N` - number of issues to show (default 5, max 25)
- `--sort stars` - sort by repo popularity/stars (default)
- `--sort updated` - sort by most recently updated

## Prerequisites

- **Git**
- **GitHub CLI (`gh`)** - install from https://cli.github.com, then `gh auth login`
- **Node.js >= 18** - for most JS/TS projects

## How it works

1. You provide keywords and an optional limit
2. The agent searches for open, beginner-friendly issues matching your keywords
3. You pick an issue to work on
4. The agent clones the repository and analyzes the codebase
5. A fix plan is proposed for your review
6. After approval, the agent implements the fix and runs tests
7. The agent creates a pull request with your changes

## Directory structure

```
oss-hunter/
├── install.sh                    # Auto-install script
├── .opencode/                    # OpenCode plugin
│   ├── INSTALL.md
│   └── plugins/oss-hunter.md
├── .claude-plugin/               # Claude Code plugin
│   ├── plugin.json
│   ├── marketplace.json
│   └── commands/oss-hunter.md
├── .cursor-plugin/               # Cursor plugin
│   └── plugin.json
├── .codex-plugin/                # Codex CLI plugin
│   ├── plugin.json
│   └── oss-hunter.md
└── .kimi-plugin/                 # Kimi Code plugin
    ├── plugin.json
    └── commands/oss-hunter.md
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
