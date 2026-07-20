# OSS Hunter

Slash command for AI coding agents to discover and fix real open-source issues.

## Supported agents

- [OpenCode](https://github.com/anomalyco/opencode)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
- [Codex CLI](https://github.com/openai/codex)
- [Kimi Code](https://kimi.moonshot.cn)

## Installation

1. Clone this repository:
   ```
   git clone https://github.com/<your-username>/oss-hunter.git
   cd oss-hunter
   ```

2. Copy the appropriate command file to your agent's commands directory:

   **OpenCode:**
   ```
   cp commands/opencode/oss-hunter.md ~/.opencode/commands/
   ```

   **Claude Code:**
   ```
   mkdir -p ~/.claude/commands
   cp commands/claude-code/oss-hunter.md ~/.claude/commands/
   ```

   **Codex CLI:**
   ```
   mkdir -p ~/.codex/commands
   cp commands/codex/oss-hunter.md ~/.codex/commands/
   ```

   **Kimi Code:**
   ```
   mkdir -p ~/.kimi/commands
   cp commands/kimi-code/oss-hunter.md ~/.kimi/commands/
   ```

3. Ensure the GitHub CLI is installed and authenticated:
   ```
   gh auth login
   ```

## Usage

Inside your agent chat, type:

```
/oss-hunter react, typescript, tailwind 10
```

The agent will guide you through finding and fixing a real open-source issue.

## Prerequisites

- **Git** - for cloning repositories
- **GitHub CLI (`gh`)** - for searching issues, cloning, forking, and creating PRs
- **Node.js >= 18** - for most JavaScript/TypeScript projects
- **Playwright** / **tmux** - the agent will help you install these when needed

## How it works

1. You provide keywords and an optional limit
2. The agent searches for open, beginner-friendly issues matching your keywords
3. You pick an issue to work on
4. The agent clones the repository and analyzes the codebase
5. A fix plan is proposed for your review
6. After approval, the agent implements the fix and runs tests
7. The agent creates a pull request with your changes

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for details on how to add support for new agents or improve the plugin.

## License

MIT
