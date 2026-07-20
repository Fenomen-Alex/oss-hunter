# OSS Hunter

Slash command for AI coding agents to discover and fix real open-source issues.

## Supported agents

- [OpenCode](https://github.com/anomalyco/opencode)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
- [Codex CLI](https://github.com/openai/codex)
- [Cursor](https://cursor.sh)
- [Kimi Code](https://kimi.moonshot.cn)

## Quick install

Run the install script:

```bash
git clone https://github.com/<your-username>/oss-hunter.git
cd oss-hunter
./install.sh
```

Or install per agent below.

---

### Claude Code

**Official marketplace** (recommended):

```
/plugin install oss-hunter@claude-plugins-official
```

**Or from repo:**

```
/plugin install https://github.com/<your-username>/oss-hunter
```

---

### OpenCode

Add to your `opencode.json`:

```json
{
  "plugin": ["oss-hunter@git+https://github.com/<your-username>/oss-hunter.git"]
}
```

Restart OpenCode. The plugin registers `/oss-hunter` automatically.

---

### Codex CLI

**Official marketplace** (recommended):

```
/plugins
```
Search for "oss-hunter" and install.

**Or from repo:**
```
mkdir -p ~/.codex/commands
cp .codex-plugin/oss-hunter.md ~/.codex/commands/
```

---

### Cursor

```
/add-plugin oss-hunter
```

Or search for "oss-hunter" in Cursor's plugin marketplace.

---

### Kimi Code

Open Kimi Code's plugin manager:

```
/plugins
```

Go to **Marketplace** > **OSS Hunter** and install.

**Or from repo:**
```
mkdir -p ~/.kimi/commands
cp .kimi-plugin/commands/oss-hunter.md ~/.kimi/commands/
```

---

## Usage

Inside your agent chat, type:

```
/oss-hunter react, typescript, tailwind 10
```

The agent will guide you through finding, fixing, and PR-ing a real open-source issue.

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
