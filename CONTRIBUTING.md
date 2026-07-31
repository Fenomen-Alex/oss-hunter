# Contributing to OSS Hunter

Thanks for your interest in contributing! Here are the ways you can help.

## Adding a new agent

1. Create a new directory under `commands/` named after your agent (e.g. `commands/my-agent/`).
2. Create an `oss-hunter.md` file containing the canonical prompt from the existing command files.
3. Adhere to your agent's custom command syntax (YAML frontmatter, allowed-tools, etc.).
4. Update the table in `README.md` with installation instructions for your agent.

## Improving the canonical prompt

The core prompt (shared across all agent command files) lives in each agent-specific file. If you update the logic, make sure to propagate changes consistently across all `commands/*/oss-hunter.md` files.

## Contribution Guide Analysis

When the plugin analyzes a repository's contribution guide, it:

1. **Fetches key files**:
   - `CONTRIBUTING.md` (primary)
   - `CODE_OF_CONDUCT.md`
   - `SECURITY.md`
   - `.github/PULL_REQUEST_TEMPLATE.md`
   - `.github/ISSUE_TEMPLATE/`
   - `DCO` or `CLA` files

2. **Extracts requirements**:
   - Forking policy
   - Branch naming convention
   - Commit message style
   - PR requirements
   - Code style/linting
   - Testing requirements
   - CLA/DCO requirements
   - Review process

3. **Presents analysis**:
   - Contribution requirements summary table
   - Potential improvements checklist

## Reporting issues

Open a GitHub issue with as much detail as possible.
