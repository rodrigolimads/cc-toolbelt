# cc-toolbelt

Custom commands and agents for [Claude Code](https://claude.ai/claude-code). Drop them into your project and go.

## What's inside

### Commands

| Command | What it does |
|---|---|
| `/dev` | Autonomous dev workflow. Takes a feature description or ticket ID, runs it through requirements, architecture, implementation, testing, and review phases with specialized agents. |
| `/ci-monitor` | Monitors a GitLab CI pipeline. Fetches job status via API, reports in a table every 5 minutes, pulls failure details when jobs finish. |

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

### Quick install (symlink into your project)

```bash
# Clone the repo
git clone git@github.com:rodrigolimads/cc-toolbelt.git ~/cc-toolbelt

# From your project root, symlink the commands and agents
mkdir -p .claude/commands .claude/agents
ln -sf ~/cc-toolbelt/commands/dev.md .claude/commands/dev.md
ln -sf ~/cc-toolbelt/commands/ci-monitor.md .claude/commands/ci-monitor.md
for agent in ~/cc-toolbelt/agents/*.md; do
  ln -sf "$agent" .claude/agents/$(basename "$agent")
done
```

### Manual install (copy files)

```bash
git clone git@github.com:rodrigolimads/cc-toolbelt.git ~/cc-toolbelt

# Copy what you need
cp ~/cc-toolbelt/commands/dev.md .claude/commands/
cp ~/cc-toolbelt/commands/ci-monitor.md .claude/commands/
cp ~/cc-toolbelt/agents/*.md .claude/agents/
```

### Install script

```bash
./install.sh /path/to/your/project
```

## Customize

These are starting points. Edit them to match your stack:

- `ci-monitor.md` references GitLab and `glab` CLI. Swap for GitHub Actions and `gh` if that's your setup.
- `/dev` agents assume Ruby/Rails + RSpec. Adjust the agent files for your framework.
- Agent personalities and review gates are configurable in `commands/dev.md`.

## License

MIT
