# Contributing to OSS Hunter

Thanks for your interest in contributing! Here are the ways you can help.

## Adding a new agent

1. Create a new directory under `commands/` named after your agent (e.g. `commands/my-agent/`).
2. Create an `oss-hunter.md` file containing the canonical prompt from the existing command files.
3. Adhere to your agent's custom command syntax (YAML frontmatter, allowed-tools, etc.).
4. Update the table in `README.md` with installation instructions for your agent.

## Improving the canonical prompt

The core prompt (shared across all agent command files) lives in each agent-specific file. If you update the logic, make sure to propagate changes consistently across all 8 command files:

- `.claude-plugin/commands/oss-hunter.md`
- `.claude-plugin/commands/oss-issue.md`
- `.opencode/plugins/oss-hunter.md`
- `.opencode/plugins/oss-issue.md`
- `.codex-plugin/oss-hunter.md`
- `.codex-plugin/oss-issue.md`
- `.kimi-plugin/commands/oss-hunter.md`
- `.kimi-plugin/commands/oss-issue.md`

## Key behaviors to preserve when editing prompts

- **Update check**: every `/oss-hunter` and `/oss-issue` invocation runs `update-check.sh check` first. If it returns `update-available`, the agent must notify the user and ask before applying. If the user declines, run `update-check.sh dismiss`. Continue silently for `up-to-date`, `dismissed`, or `offline`.
- **Multi-signal search**: three parallel `gh search issues` calls covering 12+ beginner-friendly labels, plus a semantic fallback for unlabeled issues
- **Skill verification**: cheaply verify the repo actually uses the user's claimed skills before surfacing issues
- **Deep discussion analysis**: read the full discussion and timeline, not just the last 10 comments; detect maintainer engagement, claims, PR links, scope changes, and ambiguity
- **Project health pre-screen**: evaluate stars, recent commits, CODE_OF_CONDUCT, SECURITY.md, and license before scoring
- **First-Step Readiness Score**: compute a 0-5 score across issue clarity, discussion maturity, project welcoming, setup cost, skill match, and claim risk
- **Structured handoff**: write `~/oss-projects/.handoff/<owner>-<repo>-issue-<number>.json` with triage verdict, project health, and parsed contribution guide so `/oss-issue` can short-circuit its own triage
- **Learning memory**: append every explored issue to `~/.config/oss-hunter/history.json`
- **Rate-limit awareness**: check `gh api rate_limit` before batch operations and warn if remaining calls are low
- **Structured contribution guide parsing**: extract forking policy, branch naming regex, commit style, test/lint commands, CLA/DCO, and review process from `CONTRIBUTING.md`, PR templates, and config files
- **Duplicate detection**: scan for duplicate/related issues before recommending

## Contribution Guide Analysis

When the plugin analyzes a repository's contribution guide, it:

1. **Fetches key files**:
   - `CONTRIBUTING.md` (primary)
   - `CODE_OF_CONDUCT.md`
   - `SECURITY.md`
   - `.github/PULL_REQUEST_TEMPLATE.md`
   - `.github/ISSUE_TEMPLATE/`
   - `DCO` or `CLA` files
   - `CODEOWNERS`
   - Linter/formatter configs (`.prettierrc`, `.eslintrc`, `pyproject.toml`, `golangci.yml`, etc.)
   - Test command configs (`package.json` scripts, `Makefile`, `Justfile`, `tox.ini`, `pytest.ini`, `Cargo.toml`, etc.)

2. **Extracts requirements**:
   - Forking policy
   - Branch naming convention (as regex/template if explicit)
   - Commit message style
   - PR requirements
   - Code style/linting (with detected commands)
   - Testing requirements (with detected commands)
   - CLA/DCO requirements
   - Review process
   - Labels/conventions

3. **Presents analysis**:
   - Contribution requirements summary table
   - Potential improvements checklist

## Reporting issues

Open a GitHub issue with as much detail as possible.
