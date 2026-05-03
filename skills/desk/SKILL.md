---
name: desk
version: 0.1.0
description: |
  Creates a git worktree for parallel work, each on its own branch.
  Accepts a Jira ID, a Sentry URL, or a free-text description. For
  Sentry and text inputs, opens a Jira ticket first (after a dedup
  search and a preview) so the worktree has a ticket attached. Writes
  a .desk-context.md inside the worktree so the new Claude session
  opens already knowing the ticket and source. Companion commands:
  `/desk list` and `/desk clean`. Reads `.claude/config.md` via
  `project-scanner` for per-project conventions, so the same skill
  works in any repo that has one.
license: MIT
compatibility: claude-code
allowed-tools:
  - Bash
  - Read
  - Write
  - AskUserQuestion
  - Agent
  - mcp__atlassian__getAccessibleAtlassianResources
  - mcp__atlassian__getJiraIssue
  - mcp__atlassian__createJiraIssue
  - mcp__atlassian__searchJiraIssuesUsingJql
  - mcp__atlassian__transitionJiraIssue
  - mcp__atlassian__getTransitionsForJiraIssue
  - mcp__atlassian__getJiraProjectIssueTypesMetadata
  - mcp__sentry__get_sentry_resource
---

# Desk — parallel worktrees for parallel work

You give the user a fresh "desk" for each piece of work: a sibling git
worktree on its own branch, optionally backed by a freshly-created Jira
ticket, with a context dropfile so the new Claude session starts oriented.

The mental model is exactly what the name suggests. The user already has a
desk (their primary checkout) where things live in piles. When a second
piece of work arrives, you don't disturb that desk — you bring a new one
into the room.

## Invocation modes

```
/desk <input>                   # create a desk
/desk --no-ticket <text>        # create a desk without a Jira ticket (spikes)
/desk list                      # show all active desks with their tickets
/desk clean <jira-id|path>      # remove a desk
/desk                           # no args → print this usage block
```

`<input>` is one of:

- **Jira ID** matching `[A-Z]+-\d+` (e.g., `FF-2050`) — uses an existing ticket.
- **Sentry URL** matching `sentry.io` or a self-hosted Sentry domain — fetches the issue and creates a Jira Bug.
- **Free text** (anything else) — creates a Jira Task with the text as the description.

## Phase 1 — Project discovery

Before anything else, spawn the `project-scanner` agent to discover the
host project's context. You need:

- The Jira project key for ticket creation
- Branch prefix conventions per issue type
- Default starting status for new tickets
- Worktree location pattern
- Base branch for the worktree

These come from `.claude/config.md`'s `## Worktree (/desk)` section if
present. If the section is missing or partial, prompt the user via
`AskUserQuestion` for each missing value. Do **not** invent defaults — ask.

Cache the discovered values in working memory for this run only. Do not
write them back to disk; the user edits config.md themselves.

While project-scanner runs, also resolve the Atlassian `cloudId` by
calling `getAccessibleAtlassianResources` and picking the first result.
If multiple are returned, ask which one to use.

## Phase 2 — Input detection and ticket resolution

Detect the input shape, in this order:

```
1. Matches regex ^[A-Z]+-\d+$                   → existing Jira ticket (Phase 2a)
2. Is a URL whose host contains "sentry"        → Sentry URL (Phase 2b)
3. Anything else                                → free text (Phase 2c)
```

Apply the rules top-down. The first matching rule wins. If a URL contains both
a Jira-looking key and a Sentry host, the Sentry rule applies — Jira IDs alone
should not be wrapped in URLs at the input.

### 2a. Existing Jira ticket

Call `getJiraIssue` with `issueIdOrKey` and the `cloudId`. Extract:

- Issue key (e.g., `FF-2050`)
- Summary
- Issue type name (Bug / Task / Story / etc.)

No creation, no confirmation prompt — the ticket already exists. Skip to
Phase 3.

### 2b. Sentry URL

1. Call `get_sentry_resource(url=<sentry-url>)`. Extract:
   - Issue title
   - Short ID (e.g., `PROJECT-123`)
   - Permalink
   - First-seen / last-seen timestamps if returned
   - Error type / culprit / brief stacktrace excerpt

2. **Dedup search.** Call `searchJiraIssuesUsingJql` with the JQL
   `project = <PROJECT_KEY> AND text ~ "<sentry-short-id>"`. If matches
   exist, present them via `AskUserQuestion` with options:
   - "Use existing FF-XXXX (recommended)"
   - "Create a new ticket anyway"
   - "Cancel"

3. **Build the draft.** If creating new:
   - Project: from config
   - Issue type: from config (default `Bug` for Sentry)
   - Summary: Sentry issue title (trimmed to 200 chars)
   - Description (markdown):
     ```
     **Source:** [Sentry permalink](<url>)
     **Sentry ID:** <short-id>
     **First seen:** <date>
     **Error:** <error type or culprit>

     <stacktrace excerpt, ~10 lines>
     ```

4. **Preview and confirm.** Show the user the project, issue type,
   summary, and description in a single message, then ask via
   `AskUserQuestion`:
   - "Create this ticket"
   - "Edit summary first"
   - "Cancel"

5. On confirm, call `createJiraIssue` with `contentFormat: "markdown"`.

6. Apply the starting status from config via `getTransitionsForJiraIssue`
   + `transitionJiraIssue`. If the named status (e.g., "Selected for
   Development") is not in the available transitions list, surface that
   to the user and let them pick from the actual list.

### 2c. Free text

1. **Dedup search.** Take the first 6 words of the input after dropping
   stopwords (`the, a, an, of, for, to, in, on, and, or, with, by`).
   Build a JQL query: `project = <PROJECT_KEY> AND text ~ "<those-words>"`.
   Run via `searchJiraIssuesUsingJql`. If matches exist, offer the same
   three-option choice as Sentry (use existing / create new anyway / cancel).

2. **Build the draft.**
   - Project: from config
   - Issue type: from config (default `Task` for text)
   - Summary: first sentence of input, trimmed to 120 chars
   - Description: full input verbatim

3. Preview, confirm, create, transition — same as Sentry.

### 2d. `--no-ticket` mode

Skip ticket resolution entirely. The branch and worktree slug are derived
directly from the user's text. Use a `chore/` prefix and an arbitrary
slug. No Jira interaction.

## Phase 3 — Slug and branch name

Once you have a Jira ticket (or `--no-ticket` text), build the names:

- **Lowercase Jira ID:** `FF-2050` → `ff-2050`
- **Short slug:** lowercase the summary, replace non-alphanumerics with
  `-`, collapse repeats, trim leading/trailing `-`, truncate to ~40 chars
  on a word boundary. Strip stopwords (the, a, an, of, for, to, in, on)
  if the result would otherwise exceed 40 chars.
- **Full branch name:** `<prefix>/<jira-id-lc>-<short-slug>`
- **Worktree dir name:** `<repo-basename>-<short-slug>`

Pick the prefix from the issue type using config:

```
Bug             → bugfix/
Task            → feature/
anything else   → AskUserQuestion with options [feature/, bugfix/, chore/]
```

Show the proposed branch and worktree path to the user via
`AskUserQuestion` before creating anything:

- "Use these names (recommended)"
- "Edit the slug"
- "Cancel"

## Phase 4 — Create the worktree

Substitute the values computed earlier:

- `SHORT_SLUG` — from Phase 3
- `FULL_BRANCH` — from Phase 3
- `BASE_BRANCH` — from config (typically `development`)

Run via Bash, in the host repo's working directory:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
REPO_PARENT=$(dirname "$REPO_ROOT")
REPO_NAME=$(basename "$REPO_ROOT")
WORKTREE_PATH="$REPO_PARENT/$REPO_NAME-$SHORT_SLUG"

git worktree add "$WORKTREE_PATH" -b "$FULL_BRANCH" "$BASE_BRANCH"
```

If `git worktree add` exits non-zero, do not retry silently. The most
common failure is "branch already exists" — surface the exact stderr to
the user and offer via `AskUserQuestion`:

- "Reuse existing branch (run `git worktree add $WORKTREE_PATH $FULL_BRANCH` without `-b`)"
- "Cancel — let me investigate"

For any other failure mode, surface stderr and cancel; do not attempt a fix.

## Phase 5 — Drop the context file

Write `<WORKTREE_PATH>/.desk-context.md`:

```markdown
# Desk context

- **Ticket:** [FF-2050](https://filmfreeway.atlassian.net/browse/FF-2050)
- **Title:** <ticket summary>
- **Type:** <issue type>
- **Branch:** <full branch>
- **Base:** <base branch>
- **Created:** <ISO date>
- **Source:** <one of: existing-ticket | sentry-url | free-text | no-ticket>

## Original input
<user's raw input, fenced if multi-line>

## Source link
<Sentry URL if applicable, otherwise omit>

## Project knowledge base
- `.claude/context/` — shared team knowledge
- `.claude/personal/` — personal working context
- (any other paths reported by project-scanner)
```

Then exclude it from git tracking, idempotently:

```bash
COMMON_DIR=$(git -C "$WORKTREE_PATH" rev-parse --git-common-dir)
mkdir -p "$COMMON_DIR/info"
if ! grep -qx '.desk-context.md' "$COMMON_DIR/info/exclude" 2>/dev/null; then
  echo ".desk-context.md" >> "$COMMON_DIR/info/exclude"
fi
```

Important: use `--git-common-dir`, not `--git-dir`. Vanilla git does NOT
support per-worktree `info/exclude` — it always reads from the common dir.
A file written to `<repo>/.git/worktrees/<name>/info/exclude` is silently
ignored. The path resolved here is `<repo>/.git/info/exclude`, which is
local to the user's machine (never committed, never shared with the team)
but applies across all worktrees of this repo. Net effect for
`.desk-context.md`: primary checkout doesn't have one, every desk
worktree does and they're all ignored. The dedup `grep` keeps re-runs
from accumulating duplicate lines.

## Phase 6 — Hand-off

Print to the user:

```
Desk ready: <FULL_BRANCH>
  cd <WORKTREE_PATH> && claude

Ticket: <FF-XXXX> — <summary>
Status: <current status after transition>
```

Do **not** run `cd` or launch a new Claude session yourself — the user
opens the new session in their own terminal.

## Subcommand: `/desk list`

Run `git worktree list --porcelain` from the host repo. For each linked
worktree, look for a `.desk-context.md` at its root and parse the ticket
ID and title. Print a small table:

```
PATH                                     BRANCH                            TICKET    TITLE
~/docker-work/filmfreeway                feature/ff-2049-ci-parallelization FF-2049   CI parallelization
~/docker-work/filmfreeway-fix-es-timeout bugfix/ff-2050-fix-es-timeout      FF-2050   Fix ES timeout
```

Mark the primary worktree (the one with `(bare)` or matching the host
repo path) with a `*`.

## Subcommand: `/desk clean <jira-id|path>`

1. Resolve the input to a worktree path. If a Jira ID, look it up via
   `git worktree list` plus the dropfile. If a path, normalise it.
2. Refuse to clean the primary worktree.
3. Check whether the branch is merged into the base branch:
   `git branch --merged <base> | grep <branch>`.
4. Show a confirmation block via `AskUserQuestion`:
   - "Remove worktree and delete branch (merged)" — only if step 3 was true
   - "Remove worktree, keep branch"
   - "Remove worktree, force-delete branch"
   - "Cancel"
5. Apply the chosen action:
   - `git worktree remove <path>` (or `--force` if dirty + user confirmed)
   - `git branch -d <branch>` or `git branch -D <branch>` per choice

If the worktree directory has uncommitted changes, surface them before
asking — the user must opt into `--force`.

## Phase rules

- **Ticket creation is the most expensive action.** Always preview and
  confirm before calling `createJiraIssue`. The dedup search must run
  first; do not skip it.
- **Worktree creation is locally reversible.** A failed `git worktree
  add` leaves no state behind. You can retry without cleanup.
- **Branch deletion is destructive.** Always confirm before `branch -D`.
- **Never modify the host project's `.gitignore`.** Use
  `.git/info/exclude` for the dropfile.
- **Never push branches.** The user pushes when they're ready.

## When to ask vs. when to proceed

Use `AskUserQuestion` (don't proceed silently) for:

- Any missing config value
- Ticket creation preview
- Existing-ticket dedup matches
- Slug / branch name approval
- Branch already exists
- Cleanup confirmation
- Multiple cloudIds on the Atlassian account
- Issue-type prefix when the type is neither Bug nor Task

Proceed without asking for:

- Reading config.md, .claude/context/, etc.
- The dedup JQL search itself
- Computing slugs and paths
- Writing `.desk-context.md` and the exclude line
- Running `getAccessibleAtlassianResources`, `getTransitionsForJiraIssue`

## Failure modes worth handling

- **Atlassian MCP not authenticated.** Surface the error clearly; suggest the user runs `/mcp` to check status.
- **Sentry URL but Sentry MCP not authenticated.** Tell the user; do not block on programmatic re-auth.
- **`git worktree add` fails because the branch is checked out elsewhere.** Git won't allow the same branch in two worktrees. Offer to (a) check out a fresh branch off the same base, or (b) cancel.
- **`config.md` exists but lacks the `## Worktree (/desk)` section.** Prompt for each value the first time; suggest the user adds the section to config.md afterward.
- **No `config.md` at all.** Same as above, prompt for everything. Skill still works; user gets a less polished experience.

## What this skill does NOT do

- Does not run `cd` for the user or launch a new Claude session in the worktree.
- Does not modify Docker compose files or the host project's bind mounts. The container in the host worktree continues to point at the host worktree.
- Does not push branches or open PRs.
- Does not run tests.
- Does not edit application code.
- Does not write to `config.md` or any other file outside the new worktree (except the `.git/info/exclude` line inside the new worktree).
