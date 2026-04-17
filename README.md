# cc-toolbelt

Custom commands, skills, and agents for [Claude Code](https://claude.ai/claude-code). Drop them into your project or install globally and go.

## What's inside

### Commands

| Command | What it does |
|---|---|
| `/dev` | Autonomous dev workflow. Takes a feature description or ticket ID, runs it through requirements, architecture, implementation, testing, and review phases with specialized agents. |
| `/ci-monitor` | Monitors a GitLab CI pipeline. Fetches job status via API, reports in a table every 5 minutes, pulls failure details when jobs finish. |

### Skills

| Skill | What it does |
|---|---|
| `ci-gamekeeper` | Investigates CI or local test failures and proposes minimal test-layer fixes. Pulls pipeline artifacts, cross-references the project's playbook for known patterns, classifies the failure (regression vs timing vs pollution vs DOM fragility), and stops short of staging or committing. `--auto` mode auto-applies fixes that match a playbook recipe with high confidence. Auto-invocable when CI/test-failure context is detected. |

### Agents (used by `/dev`)

| Agent | Role |
|---|---|
| `requirements-analyst` | Clarifies intent, asks probing questions, extracts acceptance criteria |
| `code-architect` | Designs implementation approach, evaluates trade-offs |
| `code-builder` | Writes production code following approved architecture |
| `test-strategist` | Plans test approach (unit vs request vs integration) |
| `test-builder` | Creates comprehensive test suites |
| `test-runner` | Runs tests, diagnoses failures, iterates until green |
| `manual-test-guide` | Creates step-by-step QA guides |
| `knowledge-base-updater` | Documents decisions and context for future sessions |

## Install

### Global (available in all projects)

```bash
git clone git@github.com:rodrigolimads/cc-toolbelt.git ~/cc-toolbelt
~/cc-toolbelt/install.sh --global
```

This symlinks commands, skills, and agents into `~/.claude/`, making `/dev`, `/ci-monitor`, and `ci-gamekeeper` available in every project you open with Claude Code.

### Per-project

```bash
~/cc-toolbelt/install.sh /path/to/your/project
```

This installs into the project's `.claude/` directory. Useful if you want to customize commands for a specific project without affecting others.

### Manual

If you prefer to copy instead of symlink:

```bash
git clone git@github.com:rodrigolimads/cc-toolbelt.git ~/cc-toolbelt

# Global
cp ~/cc-toolbelt/commands/*.md ~/.claude/commands/
cp ~/cc-toolbelt/agents/*.md ~/.claude/agents/
cp -r ~/cc-toolbelt/skills/* ~/.claude/skills/

# Or per-project
cp ~/cc-toolbelt/commands/*.md your-project/.claude/commands/
cp ~/cc-toolbelt/agents/*.md your-project/.claude/agents/
cp -r ~/cc-toolbelt/skills/* your-project/.claude/skills/
```

### Updating

Since the install script uses symlinks, pulling the latest changes is enough:

```bash
cd ~/cc-toolbelt && git pull
```

No need to reinstall. The symlinks point to the repo files, so updates take effect immediately.

## Customize

These are starting points. Fork and edit to match your stack:

- `ci-monitor.md` references GitLab and `glab` CLI. Swap for GitHub Actions and `gh` if that's your setup.
- `/dev` agents assume Ruby/Rails + RSpec. Adjust the agent files for your framework.
- Agent personalities and review gates are configurable in `commands/dev.md`.

## License

MIT
